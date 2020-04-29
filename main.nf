#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/cageseq
========================================================================================
 nf-core/cageseq Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/nf-core/cageseq
----------------------------------------------------------------------------------------
*/

def helpMessage() {

    log.info nfcoreHeader()
    log.info"""

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/cageseq --reads '*_R{1,2}.fastq.gz' --aligner star --genome GRCh38 -profile docker

    Mandatory arguments:
        --reads [file]                    Path to input data (must be surrounded with quotes)
        -profile [str]                    Configuration profile to use. Can use multiple (comma separated)
                                          Available: conda, docker, singularity, test, awsbatch, <institute> and more

    Trimming:
        --skip_trimming [bool]          Set to true to skip all file trimming steps
        --save_trimmed                  Set to true to Save trimmed FastQ files
        --trim_ecop [bool]              Set to false to not trim the EcoP site
        --trim_linker [bool]            Set to false to not trim the linker
        --trim_5g [bool]                Set to false to not trim the additonal G at the 5' end
        --trim_artifacts [bool]         Set to false to not trim artifacts
        --artifacts_5end [file]         Path to 5 end artifact file, if not given the pipeline will use a default file with all possible artifacts
        --artifacts_3end [file]         Path to 3 end artifact file, if not given the pipeline will use a default file with all possible artifacts

    References                          If not specified in the configuration file or you wish to overwrite any of the references
        --fasta [file]                  Path to fasta reference
        --genome [str]               Name of iGenomes reference
        --gtf [file]                    Path to gtf file

    Alignment:
        --aligner [str]              Specifies the aligner to use (available are: 'star', 'bowtie')
        --star_index [file]             Path to STAR index, set to false if igenomes should be used
        --bowtie_index [file]           Path to bowtie index, set to false if igenomes should be used

    Clustering:
        --min_cluster [int]                  Minimum amount of reads to build a cluster with paraclu
        --tpm_cluster_threshold [int]         Threshold for expression count of ctss considered in paraclu clustering

    Other options:
        --outdir [file]                 The output directory where the results will be saved
        --email [email]                 Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
        --email_on_fail [email]         Same as --email, except only send mail if the workflow is not successful
        --max_multiqc_email_size [str]  Theshold size for MultiQC report to be attached in notification email. If file generated by pipeline exceeds the threshold, it will not be attached (Default: 25MB)
        -name [str]                     Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic

    AWSBatch options:
        --awsqueue [str]                The AWSBatch JobQueue that needs to be set when running on AWSBatch
        --awsregion [str]               The AWS Region for your AWS Batch job to run on
        --awscli [str]                  Path to the AWS CLI tool
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Check if genome exists in the config file
if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
    exit 1, "The provided genome '${params.genome}' is not available in the iGenomes file. Currently the available genomes are ${params.genomes.keySet().join(", ")}"
}

params.star_index = params.genome ? params.genomes[ params.genome ].star ?: false : false
params.bowtie_index = params.genome ? params.genomes[ params.genome ].bowtie ?: false : false
params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false
if (params.fasta) { ch_fasta = file(params.fasta, checkIfExists: true) }
params.gtf = params.genome ? params.genomes[ params.genome ].gtf ?: false : false
//params.artifacts_5end = params.artifacts_5end ? params.artifacts_5end[ params.artifacts_5end ].fasta ?: false : false
//params.artifacts_3end = params.artifacts_3end ? params.artifacts_3end[ params.artifacts_3end ].fasta ?: false : false
params.min_cluster = 30
params.tpm_cluster_threshold = 0.2

// Validate inputs
if (params.aligner != 'star' && params.aligner != 'bowtie') {
    exit 1, "Invalid aligner option: ${params.aligner}. Valid options: 'star', 'bowtie'"
}
if( params.star_index && params.aligner == 'star' ){
    star_index = Channel
        .fromPath(params.star_index, checkIfExists: true)
        .ifEmpty { exit 1, "STAR index not found: ${params.star_index}" }
}
else if( params.bowtie_index && params.aligner == 'bowtie' ){
    bowtie_index = Channel
        .fromPath(params.bowtie_index, checkIfExists: true)
        .ifEmpty { exit 1, "STAR index not found: ${params.bowtie_index}" }
}
else if ( params.fasta ){
    Channel
        .fromPath(params.fasta, checkIfExists: true)
        .ifEmpty { exit 1, "fasta file not found: ${params.fasta}" }
        .into { fasta_star_index; fasta_bowtie_index}
}
else {
    exit 1, "No reference genome specified!"
}


if( params.fasta ){
  fasta_rseqc = Channel
      .fromPath(params.fasta, checkIfExists: true)
      .ifEmpty { exit 1, "fasta file not found: ${params.fasta}" }
} else {
    exit 1, "No fasta file specified!"
}

if( params.gtf ){
    Channel
        .fromPath(params.gtf, checkIfExists: true)
        .ifEmpty { exit 1, "GTF annotation file not found: ${params.gtf}" }
        .into { gtf_makeSTARindex; gtf_star; gtf_rseqc}
} else {
    exit 1, "No GTF annotation specified!"
}

if( params.artifacts_5end ){
    ch_5end_artifacts = Channel
        .fromPath(params.artifacts_5end)
}
else {
    ch_5end_artifacts = Channel
        .fromPath("$baseDir/assets/artifacts_5end.fasta")
}

if( params.artifacts_3end ){
     ch_3end_artifacts = Channel
        .fromPath(params.artifacts_3end)
}
else {
    ch_3end_artifacts = Channel
        .fromPath("$baseDir/assets/artifacts_3end.fasta")
}



// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
    custom_runName = workflow.runName
}

if (workflow.profile.contains('awsbatch')) {
    // AWSBatch sanity checking
    if (!params.awsqueue || !params.awsregion) exit 1, "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
    // Check outdir paths to be S3 buckets if running on AWSBatch
    // related: https://github.com/nextflow-io/nextflow/issues/813
    if (!params.outdir.startsWith('s3:')) exit 1, "Outdir not on S3 - specify S3 Bucket to run on AWSBatch!"
    // Prevent trace files to be stored on S3 since S3 does not support rolling files.
    if (params.tracedir.startsWith('s3:')) exit 1, "Specify a local tracedir or run without trace! S3 cannot be used for tracefiles."
}


// Stage config files
ch_multiqc_config = file("$baseDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
ch_output_docs = file("$baseDir/docs/output.md", checkIfExists: true)

/*
 * Create a channel for input read files
 */

if(params.readPaths){
         Channel
             .from(params.readPaths)
             .map { row -> [ row[0], file(row[1])] }
             .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
             .into { read_files_fastqc; read_files_trimming }
     } else {
         Channel
            .fromFilePairs( params.reads )
            .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\n" }
            .into { read_files_fastqc; read_files_trimming }
}

// Header log info
log.info nfcoreHeader()
def summary = [:]
summary['Run Name']        = custom_runName ?: workflow.runName
if (params.genome){summary['Reads'] = params.reads}
if (params.aligner == 'star') {
    summary['Aligner'] = "STAR"
    if (params.star_index){summary['STAR Index'] = params.star_index}
    else if (params.fasta){summary['Fasta Ref'] = params.fasta}
} else if (params.aligner == 'bowtie') {
    summary['Aligner'] = "bowtie"
    if (params.bowtie_index)summary['bowtie Index'] = params.bowtie_index
    else if (params.fasta)summary['Fasta Ref'] = params.fasta
    if (params.splicesites)summary['Splice Sites'] = params.splicesites
}
if(params.artifacts_5end){ summary["5' artifacts"] = params.artifacts_5end}
if(params.artifacts_3end){ summary["3' artifacts"] = params.artifacts_3end}
summary['trim_ecop']        = params.trim_ecop
summary['trim_linker']      = params.trim_linker
summary['trim_5g']          = params.trim_5g
summary['trim_artifacts']   = params.trim_artifacts
summary['EcoSite']          = params.ecoSite
summary['LinkerSeq']        = params.linkerSeq
summary['Min. cluster']     = params.min_cluster
summary['Cluster Threshold [tpm]']= params.tpm_cluster_threshold
summary['Save Reference']   = params.saveReference
summary['Max Resources']    = "$params.max_memory memory, $params.max_cpus cpus, $params.max_time time per job"
if (workflow.containerEngine) summary['Container'] = "$workflow.containerEngine - $workflow.container"
summary['Output dir']       = params.outdir
summary['Launch dir']       = workflow.launchDir
summary['Working dir']      = workflow.workDir
summary['Script dir']       = workflow.projectDir
summary['User']             = workflow.userName
if (workflow.profile.contains('awsbatch')) {
    summary['AWS Region']   = params.awsregion
    summary['AWS Queue']    = params.awsqueue
    summary['AWS CLI']      = params.awscli
}
summary['Config Profile'] = workflow.profile
if (params.config_profile_description) summary['Config Description'] = params.config_profile_description
if (params.config_profile_contact)     summary['Config Contact']     = params.config_profile_contact
if (params.config_profile_url)         summary['Config URL']         = params.config_profile_url
if (params.email || params.email_on_fail) {
    summary['E-mail Address']    = params.email
    summary['E-mail on failure'] = params.email_on_fail
    summary['MultiQC maxsize']   = params.max_multiqc_email_size
}
log.info summary.collect { k,v -> "${k.padRight(18)}: $v" }.join("\n")
log.info "-\033[2m--------------------------------------------------\033[0m-"

// Check the hostnames against configured profiles
checkHostname()

Channel.from(summary.collect{ [it.key, it.value] })
    .map { k,v -> "<dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }
    .reduce { a, b -> return [a, b].join("\n            ") }
    .map { x -> """
    id: 'nf-core-cageseq-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'nf-core/cageseq Workflow Summary'
    section_href: 'https://github.com/nf-core/cageseq'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
            $x
        </dl>
    """.stripIndent() }
    .set { ch_workflow_summary }

process get_software_versions {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy',
        saveAs: { filename ->
                      if (filename.indexOf(".csv") > 0) filename
                      else null
                }

    output:
    file 'software_versions_mqc.yaml' into ch_software_versions_yaml
    file "software_versions.csv"

    script:
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    fastqc --version > v_fastqc.txt
    multiqc --version > v_multiqc.txt
    STAR --version > v_star.txt
    bowtie --version > v_bowite.txt
    cutadapt --version > v_cutadapt.txt
    samtools --version > v_samtools.txt
    bedtools --version > v_bedtools.txt
    read_distribution.py --version > v_rseqc.txt
    python bin/scrape_software_versions.py &> software_versions_mqc.yaml
    """
}
process convert_gtf {
    tag "$gtf"

    input:
    file gtf from gtf_rseqc

    output:
    file "${gtf.baseName}.bed" into bed_rseqc

    script: // This script is bundled with the pipeline, in nfcore/cageseq/bin/
    """
    gtf2bed.pl $gtf > ${gtf.baseName}.bed
    """
}

/*
 * STEP 1 - FastQC
 */
process fastqc {
    tag "$sample_name"
    label 'process_medium'
    publishDir "${params.outdir}/fastqc", mode: 'copy',
        saveAs: { filename ->
                      filename.indexOf(".zip") > 0 ? "zips/$filename" : "$filename"
                }

    input:
    set val(sample_name), file(reads) from read_files_fastqc

    output:
    file "*_fastqc.{zip,html}" into ch_fastqc_results

    script:
    """
    fastqc --quiet --threads $task.cpus $reads
    """
}


/*
 * STEP 2  - Build STAR index
 */

if(params.aligner == 'star' && !params.star_index && params.fasta){
    process makeSTARindex {
        label 'high_memory'
        tag "${fasta.baseName}"
        publishDir path: { params.saveReference ? "${params.outdir}/reference_genome" : params.outdir },
                saveAs: { params.saveReference ? it : null }, mode: 'copy'

        input:
        file fasta from fasta_star_index
        file gtf from gtf_makeSTARindex.collect()

        output:
        file "star" into star_index

        when:


        script:
        def avail_mem = task.memory ? "--limitGenomeGenerateRAM ${task.memory.toBytes() - 100000000}" : ''
        """
        mkdir star
        STAR \\
            --runMode genomeGenerate \\
            --runThreadN ${task.cpus} \\
            --sjdbGTFfile $gtf \\
            --genomeDir star/ \\
            --genomeFastaFiles $fasta \\
            $avail_mem
        """
    }
}

if(params.aligner == 'bowtie' && !params.bowtie_index && params.fasta){
    process makeBowtieindex {
        tag "${fasta.baseName}"
        publishDir path: { params.saveReference ? "${params.outdir}/reference_genome" : params.outdir },
                saveAs: { params.saveReference ? it : null }, mode: 'copy'

        input:
        file fasta from fasta_bowtie_index

        output:
        file "${fasta.baseName}.index*" into bowtie_index
        when:


        script:
        """


        bowtie-build --threads ${task.cpus} ${fasta} ${fasta.baseName}.index


        """
    }
}

/*
 * STEP 3 - Cut Enzyme binding site at 5' and linker at 3'
 */

if(!params.skip_trimming){
    process trim_adapters {
        tag "$sample_name"
        publishDir "${params.outdir}/trimmed/adapter_trimmed", mode: 'copy',
                saveAs: {filename ->
                    if (filename.indexOf(".fastq.gz") == -1)    "logs/$filename"
                    else if (!params.save_trimmed) "$filename"
                    else null
                }

        input:
        set val(sample_name), file(reads) from read_files_trimming

        output:
        set val(sample_name), file("*.fastq.gz") into trimmed_reads_trim_5g
        file "*.output.txt" into cutadapt_results

        script:
        prefix = reads.baseName.toString() - ~/(\.fq)?(\.fastq)?(\.gz)?$/
        // Cut Both EcoP and Linker
        if (params.trim_ecop && params.trim_linker){
            """
            cutadapt -a ${params.ecoSite}...${params.linkerSeq} \\
            --match-read-wildcards \\
            -m 15 -M 45  \\
            -o "$prefix".adapter_trimmed.fastq.gz \\
            $reads \\
            > "$prefix"_adapter_trimming.output.txt
            """
        }

        // Cut only EcoP site
        else if (params.trim_ecop && !params.trim_linker){
            """
            mkdir trimmed
            cutadapt -g ^${params.ecoSite} \\
            -e 0 \\
            --match-read-wildcards \\
            --discard-untrimmed \\
            -o "$prefix".adapter_trimmed.fastq.gz \\
            $reads \\
            > "$prefix"_adapter_trimming.output.txt
            """
        }

        // Cut only Linker
        else if (!params.trim_ecop && params.trim_linker){
            """
            mkdir trimmed
            cutadapt -a ${params.linkerSeq}\$ \\
            -e 0 \\
            --match-read-wildcards \\
            -m 15 -M 45 \\
            -o "$prefix".adapter_trimmed.fastq.gz \\
            $reads \\
            > "$prefix"_adapter_trimming.output.txt
            """
        }
    }
} else {
    read_files_trimming.set{ trimmed_reads_trim_5g }
    cutadapt_results = Channel.empty()
}

  /**
   * STEP 4 - Remove added G from 5-end
   */
  if (params.trim_5g && !params.skip_trimming){
      process trim_5g{
        tag "$sample_name"
        publishDir "${params.outdir}/trimmed/g_trimmed", mode: 'copy',
                saveAs: {filename ->
                    if (filename.indexOf(".fastq.gz") == -1)    "logs/$filename"
                    else if (!params.save_trimmed) "$filename"
                    else null
                }
          input:
          set val(sample_name), file(reads) from trimmed_reads_trim_5g

          output:
          set val(sample_name), file("*.fastq.gz") into processed_reads

          script:
          prefix = reads.baseName.toString() - ~/(\.fq)?(\.fastq)?(\.gz)?(\.trimmed)?$/
          """
          cutadapt -g ^G \\
          -e 0 --match-read-wildcards --discard-trimmed \\
          --cores=${task.cpus} \\
          -o "$prefix".g_trimmed.fastq.gz \\
          $reads \\
          > ${reads.baseName}.g_trimming.output.txt
          """
      }
  }
  else {
      trimmed_reads_trim_5g.set{processed_reads}
  }
  /**
   * STEP 5 - Remove artifacts
   */

if (params.trim_artifacts && !params.skip_trimming){
    process trim_artifacts {
        tag "$sample_name"
        publishDir "${params.outdir}/trimmed/artifacts_trimmed", mode: 'copy',
          saveAs: {filename ->
              if (filename.indexOf(".fastq.gz") == -1)    "logs/$filename"
              else if (!params.save_trimmed) "$filename"
              else null
          }

        input:
        set val(sample_name), file(reads) from processed_reads
        file artifacts_5end from ch_5end_artifacts.collect()
        file artifacts_3end from ch_3end_artifacts.collect()

        output:
        set val(sample_name), file("*.fastq.gz") into further_processed_reads
        file  "*.output.txt" into artifact_cutting_results

        script:
        prefix = reads.baseName.toString() - ~/(\.fq)?(\.fastq)?(\.gz)?(\.trimmed)?(\.processed)?$/
        """
        cutadapt -a file:$artifacts_3end \\
        -g file:$artifacts_5end -e 0.1 --discard-trimmed \\
        --match-read-wildcards -m 15 -O 19 \\
        --cores=${task.cpus} \\
        -o "$prefix".artifacts_trimmed.fastq.gz \\
        $reads \\
        > ${reads.baseName}.artifacts_trimming.output.txt
        """
    }
    further_processed_reads.into { further_processed_reads_star;further_processed_reads_bowtie; further_processed_reads_fastqc }
}
else{
    processed_reads.into{further_processed_reads_star; further_processed_reads_bowtie; further_processed_reads_fastqc}
    artifact_cutting_results = Channel.empty()
}

// Post trimming QC, only needed if some trimming has been done
process trimmed_fastqc {
    tag "$sample_name"
    publishDir "${params.outdir}/trimmed/fastqc", mode: 'copy',
          saveAs: {filename -> filename.indexOf(".zip") > 0 ? "zips/$filename" : "$filename"}

    input:
    set val(sample_name), file(reads) from further_processed_reads_fastqc

    output:
    set val(sample_name), file("*_fastqc.{zip,html}") into trimmed_fastqc_results

    when:
    (params.trim_5g || params.trim_artifacts) && !params.skip_trimming
    script:
    """
    fastqc -q $reads
    """
}

/**
 * STEP 7 - STAR alignment
 */
further_processed_reads_star = further_processed_reads_star.dump(tag:"star")
if (params.aligner == 'star') {
    process star {
        label 'high_memory'
        tag "$sample_name"
        publishDir "${params.outdir}/STAR", mode: 'copy',
                saveAs: {filename ->
                    if (filename.indexOf(".bam") == -1) "logs/$filename"
                    else  filename }

        input:
        set val(sample_name), file(reads) from further_processed_reads_star
        file index from star_index.collect()
        file gtf from gtf_star.collect()

        output:
        set val(sample_name), file("*.bam") into star_aligned
        file "*.out" into star_alignment_logs
        file "*SJ.out.tab"


        script:

        prefix = reads[0].toString() - ~/(.trimmed)?(\.fq)?(\.fastq)?(\.gz)?(\.processed)?(\.further_processed)?$/

        """
        STAR --genomeDir $index \\
            --sjdbGTFfile $gtf \\
            --readFilesIn $reads \\
            --runThreadN ${task.cpus} \\
            --outSAMtype BAM SortedByCoordinate \\
            --outFilterScoreMinOverLread 0 --outFilterMatchNminOverLread 0 \\
            --outFilterMismatchNmax 1 \\
            --readFilesCommand zcat \\
            --runDirPerm All_RWX \\
            --outFileNamePrefix $prefix \\
            --outFilterMatchNmin ${params.min_aln_length}
        """

    }

    star_aligned.into { bam_stats; bam_aligned }
} else{
    star_alignment_logs = Channel.empty()
}
if (params.aligner == 'bowtie'){
process bowtie {
    label 'high_memory'
    tag "$sample_name"
    publishDir "${params.outdir}/bowtie", mode: 'copy',
            saveAs: {filename ->
                if (filename.indexOf(".bam") == -1) "logs/$filename"
                else  filename }

    input:
    set val(sample_name), file(reads) from further_processed_reads_bowtie
    file index_array from bowtie_index.collect()

    output:
    set val(sample_name), file("*.bam") into bam_stats, bam_aligned
    file "*.out" into bowtie_alignment_logs


    script:

    prefix = reads[0].toString() - ~/(.trimmed)?(\.fq)?(\.fastq)?(\.gz)?(\.processed)?(\.further_processed)?$/
    index = index_array[0].baseName - ~/.\d$/
    """
    bowtie --sam \\
        -m 1 \\
        --best \\
        --strata \\
        -k 1 \\
        --tryhard \\
        --threads ${task.cpus} \\
        --phred33-quals \\
        --chunkmbs 64 \\
        --seedmms 2 \\
        --seedlen 28 \\
        --maqerr 70  \\
        ${index}  \\
        -q ${reads} \\
        --un ${reads.baseName}.unAl > ${sample_name}.sam 2> ${sample_name}.out

        samtools sort -@ ${task.cpus} -o ${sample_name}.bam ${sample_name}.sam
    """

}
}else{
    bowtie_alignment_logs= Channel.empty()
}

process samtools_stats {
    tag "$sample_name"
    label 'process_medium'

    input:
    set val(sample_name), file(bam_count) from bam_stats

    output:
    file "*.{flagstat,idxstats,stats}" into bam_flagstat_mqc

    script:
    """
    samtools idxstats $bam_count > ${bam_count}.idxstats
    samtools stats $bam_count > ${bam_count}.stats
    """
}

/**
 * STEP 8 - Get CTSS files
 */
process get_ctss {
    tag "$sample_name"
    publishDir "${params.outdir}/ctss", mode: 'copy'

    input:
    set val(sample_name), file(bam_count) from bam_aligned

    output:
    set val(sample_name), file("*.ctss.bed") into ctss_samples
    file("*.ctss.bed") into ctss_counts, ctss_counts_qc

    script:
    """
    make_ctss.sh -q 20 -i ${bam_count.baseName} -n ${sample_name}
    """
}

/**
 * STEP 9 - Cluster CTSS files
 */
ctss_counts = ctss_counts.collect().dump(tag:"ctss_counts")
process cluster_ctss {
    label "high_memory"
    tag "${ctss}"
    publishDir "${params.outdir}/ctss/clusters", mode: 'copy'

    input:
    file ctss from ctss_counts.collect()

    output:
    file "*.bed" into ctss_clusters


    shell:
    '''
    process_ctss.sh -t !{params.tpm_cluster_threshold} !{ctss}

    paraclu !{params.min_cluster} "ctss_all_pos_4Ps" > "ctss_all_pos_clustered"
    paraclu !{params.min_cluster} "ctss_all_neg_4Ps" > "ctss_allneg_clustered"

    paraclu-cut.sh  "ctss_all_pos_clustered" >  "ctss_all_pos_clustered_simplified"
    paraclu-cut.sh  "ctss_all_neg_clustered" >  "ctss_all_neg_clustered_simplified"

    cat "ctss_all_pos_clustered_simplified" "ctss_all_neg_clustered_simplified" >  "ctss_all_clustered_simplified"
    awk -F '\t' '{print $1"\t"$3"\t"$4"\t"$1":"$3".."$4","$2"\t"$6"\t"$2}' "ctss_all_clustered_simplified" >  "ctss_all_clustered_simplified.bed"
    '''
}



 /*
  * STEP 11 - Generate count files
  */
 process generate_counts {
    tag "${sample_name}"
    // publishDir "${params.outdir}/ctss/", mode: 'copy'

    input:
    set val(sample_name), file(ctss) from ctss_samples
    file clusters from ctss_clusters.collect()

    output:
    file "*.txt" into count_files
    file "*.bed" into count_qc

    shell:
    '''
    #intersect ctss files with generated clusters
    intersectBed -a !{clusters} -b !{ctss} -loj -s > !{ctss}_counts_tmp

    echo !{sample_name} > !{ctss}_counts.txt

    bedtools groupby -i !{ctss}_counts_tmp -g 1,2,3,4,6 -c 11 -o sum > !{ctss}_counts.bed
    awk -v OFS='\t' '{if($6=="-1") $6=0; print $6 }' !{ctss}_counts.bed >> !{ctss}_counts.txt
    '''
 }

/*
 * STEP 11 - Generate count matrix
 */
process generate_count_matrix {
    tag "${counts}"
    publishDir "${params.outdir}/ctss/", mode: 'copy'

    input:
    file counts from count_files.collect()
    file clusters from ctss_clusters.collect()

    output:
    file "*.txt" into count_matrix

    shell:
    '''
    awk '{ print $4}' !{clusters} > coordinates
    paste -d "\t" coordinates !{counts} >> count_table.txt
    '''
}

/**
 * STEP 10 - QC for clustered ctss
 */
process ctss_qc {
    tag "$clusters"
    publishDir "${params.outdir}/rseqc" , mode: 'copy',
     saveAs: {filename ->
              if (filename.indexOf("read_distribution.txt") > 0) "read_distribution/$filename"
              else filename
     }

    input:
    file clusters from ctss_counts_qc
    file gtf from bed_rseqc.collect()
    file fasta from fasta_rseqc.collect()

    output:
    file "*.txt" into rseqc_results

    shell:
    '''
    cat !{fasta} |  awk '$0 ~ ">" {if (NR > 1) {print c;} c=0;printf substr($0,2,100) "\t"; } $0 !~ ">" {c+=length($0);} END { print c; }' > chrom_sizes.tmp
    bedtools bedtobam -i !{clusters} -g chrom_sizes.tmp > !{clusters.baseName}.bam
    read_distribution.py -i !{clusters.baseName}.bam -r !{gtf} > !{clusters.baseName}.read_distribution.txt
    '''
 }

/*
 * STEP 12 - MultiQC
 */
process multiqc {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    input:
    file multiqc_config from ch_multiqc_config
    file (mqc_custom_config) from ch_multiqc_custom_config.collect().ifEmpty([])
    file ('software_versions/*') from ch_software_versions_yaml.collect()
    file ('fastqc/*') from ch_fastqc_results.collect().ifEmpty([])
    file ('trimmed/*') from cutadapt_results.collect().ifEmpty([])
    file ('artifacts_trimmed/*') from  artifact_cutting_results.collect().ifEmpty([])
    file ('trimmed/fastqc/*') from trimmed_fastqc_results.collect().ifEmpty([])
    file ('alignment/*') from star_alignment_logs.collect().ifEmpty([])
    file ('alignment/*') from bowtie_alignment_logs.collect().ifEmpty([])
    file ('alignment/samtools_stats/*') from bam_flagstat_mqc.collect().ifEmpty([])
    file ('rseqc/*') from rseqc_results.collect().ifEmpty([])
    file workflow_summary from ch_workflow_summary.collectFile(name: "workflow_summary_mqc.yaml")

    output:
    file "*multiqc_report.html" into ch_multiqc_report
    file "*_data"
    file "multiqc_plots"

    script:
    rtitle = custom_runName ? "--title \"$custom_runName\"" : ''
    rfilename = custom_runName ? "--filename " + custom_runName.replaceAll('\\W','_').replaceAll('_+','_') + "_multiqc_report" : ''
    custom_config_file = params.multiqc_config ? "--config $mqc_custom_config" : ''

    """
    multiqc -f $rtitle $rfilename $custom_config_file \\
    -m custom_content -m fastqc -m star -m cutadapt -m rseqc -m samtools -m bowtie1 .
    """
}

/*
 * STEP 11 - Output Description HTML
 */
process output_documentation {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    input:
    file output_docs from ch_output_docs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.py $output_docs -o results_description.html
    """
}

/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[nf-core/cageseq] Successful: $workflow.runName"
    if (!workflow.success) {
        subject = "[nf-core/cageseq] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if (workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if (workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if (workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // On success try attach the multiqc report
    def mqc_report = null
    try {
        if (workflow.success) {
            mqc_report = ch_multiqc_report.getVal()
            if (mqc_report.getClass() == ArrayList) {
                log.warn "[nf-core/cageseq] Found multiple reports from process 'multiqc', will use only one"
                mqc_report = mqc_report[0]
            }
        }
    } catch (all) {
        log.warn "[nf-core/cageseq] Could not attach MultiQC report to summary email"
    }

    // Check if we are only sending emails on failure
    email_address = params.email
    if (!params.email && params.email_on_fail && !workflow.success) {
        email_address = params.email_on_fail
    }

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: email_address, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir", mqcFile: mqc_report, mqcMaxSize: params.max_multiqc_email_size.toBytes() ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (email_address) {
        try {
            if (params.plaintext_email) { throw GroovyException('Send plaintext e-mail, not HTML') }
            // Try to send HTML e-mail using sendmail
            [ 'sendmail', '-t' ].execute() << sendmail_html
            log.info "[nf-core/cageseq] Sent summary e-mail to $email_address (sendmail)"
        } catch (all) {
            // Catch failures and try with plaintext
            [ 'mail', '-s', subject, email_address ].execute() << email_txt
            log.info "[nf-core/cageseq] Sent summary e-mail to $email_address (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File("${params.outdir}/pipeline_info/")
    if (!output_d.exists()) {
        output_d.mkdirs()
    }
    def output_hf = new File(output_d, "pipeline_report.html")
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File(output_d, "pipeline_report.txt")
    output_tf.withWriter { w -> w << email_txt }

    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_red = params.monochrome_logs ? '' : "\033[0;31m";
    c_reset = params.monochrome_logs ? '' : "\033[0m";

    if (workflow.stats.ignoredCount > 0 && workflow.success) {
        log.info "-${c_purple}Warning, pipeline completed, but with errored process(es) ${c_reset}-"
        log.info "-${c_red}Number of ignored errored process(es) : ${workflow.stats.ignoredCount} ${c_reset}-"
        log.info "-${c_green}Number of successfully ran process(es) : ${workflow.stats.succeedCount} ${c_reset}-"
    }

    if (workflow.success) {
        log.info "-${c_purple}[nf-core/cageseq]${c_green} Pipeline completed successfully${c_reset}-"
    } else {
        checkHostname()
        log.info "-${c_purple}[nf-core/cageseq]${c_red} Pipeline completed with errors${c_reset}-"
    }

}


def nfcoreHeader() {
    // Log colors ANSI codes
    c_black = params.monochrome_logs ? '' : "\033[0;30m";
    c_blue = params.monochrome_logs ? '' : "\033[0;34m";
    c_cyan = params.monochrome_logs ? '' : "\033[0;36m";
    c_dim = params.monochrome_logs ? '' : "\033[2m";
    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_reset = params.monochrome_logs ? '' : "\033[0m";
    c_white = params.monochrome_logs ? '' : "\033[0;37m";
    c_yellow = params.monochrome_logs ? '' : "\033[0;33m";

    return """    -${c_dim}--------------------------------------------------${c_reset}-
                                            ${c_green},--.${c_black}/${c_green},-.${c_reset}
    ${c_blue}        ___     __   __   __   ___     ${c_green}/,-._.--~\'${c_reset}
    ${c_blue}  |\\ | |__  __ /  ` /  \\ |__) |__         ${c_yellow}}  {${c_reset}
    ${c_blue}  | \\| |       \\__, \\__/ |  \\ |___     ${c_green}\\`-._,-`-,${c_reset}
                                            ${c_green}`._,._,\'${c_reset}
    ${c_purple}  nf-core/cageseq v${workflow.manifest.version}${c_reset}
    -${c_dim}--------------------------------------------------${c_reset}-
    """.stripIndent()
}

def checkHostname() {
    def c_reset = params.monochrome_logs ? '' : "\033[0m"
    def c_white = params.monochrome_logs ? '' : "\033[0;37m"
    def c_red = params.monochrome_logs ? '' : "\033[1;91m"
    def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
    if (params.hostnames) {
        def hostname = "hostname".execute().text.trim()
        params.hostnames.each { prof, hnames ->
            hnames.each { hname ->
                if (hostname.contains(hname) && !workflow.profile.contains(prof)) {
                    log.error "====================================================\n" +
                            "  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
                            "  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
                            "  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
                            "============================================================"
                }
            }
        }
    }
}
