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

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowCageseq.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input, params.multiqc_config,
    params.fasta, params.gtf,
    params.ribo_database_manifest,
    params.star_index, params.bowtie_index,
    params.artifacts_5end, params.artifacts_3end
    ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

// Check rRNA databases for sortmerna
if (params.remove_ribo_rna) {
    ch_ribo_db = file(params.ribo_database_manifest, checkIfExists: true)
    if (ch_ribo_db.isEmpty()) {exit 1, "File provided with --ribo_database_manifest is empty: ${ch_ribo_db.getName()}!"}
}

// Check alignment parameters
def prepareToolIndices  = []
if (!params.skip_alignment) { prepareToolIndices << params.aligner }

// Save AWS IGenomes file containing annotation version
def anno_readme = params.genomes[ params.genome ]?.readme
if (anno_readme && file(anno_readme).exists()) {
    file("${params.outdir}/genome/").mkdirs()
    file(anno_readme).copyTo("${params.outdir}/genome/")
}


/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/modules/fastqc/main'
include { FASTQC as FASTQC_POST       } from '../modules/nf-core/modules/fastqc/main'
include { SAMTOOLS_SORT               } from '../modules/nf-core/modules/samtools/sort/main'
include { RSEQC_READDISTRIBUTION      } from '../modules/nf-core/modules/rseqc/readdistribution/main'
include { SORTMERNA                   } from '../modules/nf-core/modules/sortmerna/main'
include { STAR_ALIGN                  } from '../modules/nf-core/modules/star/align/main'
include { BOWTIE_ALIGN                } from '../modules/nf-core/modules/bowtie/align/main'
include { MULTIQC                     } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

//
// SUBWORKFLOWS: Consisting entirely of nf-core/modules
//
include { TRIMMING_PREPROCESSING } from '../subworkflows/local/trimming'
include { BAM_SORT_SAMTOOLS      } from '../subworkflows/local/bam_sort_samtools'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
include { PREPARE_GENOME } from '../subworkflows/local/prepare_genome'
include { GENERATE_CTSS  } from '../subworkflows/local/generate_ctss'
include { CLUSTER_TAGS   } from '../subworkflows/local/cluster_tags'

//=====================================================//
/* CAGE-seq workflow */
//=====================================================//

// Info required for completion email and summary
def multiqc_report      = []

workflow CAGESEQ {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    .reads
    .map {
        meta, fastq ->
            meta.id = meta.id.split('_')[0..-2].join('_')
            meta.single_end = true // needed for some modules
            [ meta, fastq ] }
    .groupTuple(by: [0])
    .map {
        meta, fastq ->
            [ meta, fastq.flatten() ]
    }
    .set { ch_fastq }
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: Run FastQC
    //
    if (!(params.skip_initial_fastqc || params.skip_qc)) {
        FASTQC (
            INPUT_CHECK.out.reads
        )
        ch_versions = ch_versions.mix(FASTQC.out.versions.first())
    }

    //
    // SUBWORKFLOW: Trim adapters
    //
    TRIMMING_PREPROCESSING (
        ch_fastq,
        params.artifacts_5end,
        params.artifacts_3end,
        params.trim_ecop || params.trim_linker,
        params.trim_5g,
        params.trim_artifacts,
        params.skip_trimming
    )
    ch_versions = ch_versions.mix(TRIMMING_PREPROCESSING.out.versions)
    ch_filtered_reads = TRIMMING_PREPROCESSING.out.reads

    //
    // MODULE: Remove ribosomal RNA reads
    //
    ch_sortmerna_multiqc = Channel.empty()
    if (params.remove_ribo_rna) {
        ch_sortmerna_fastas = Channel.from(ch_ribo_db.readLines()).map { row -> file(row, checkIfExists: true) }.collect()

        SORTMERNA (
            ch_filtered_reads,
            ch_sortmerna_fastas
        )
        .reads
        .set { ch_filtered_reads }

        ch_sortmerna_multiqc = SORTMERNA.out.log
        ch_versions = ch_versions.mix(SORTMERNA.out.versions.first())
    }


    //
    // MODULE: Run FastQC after filtering and trimming
    //
    if (!(params.skip_fastqc || params.skip_qc || params.skip_trimming_fastqc || params.skip_trimming)) {
        FASTQC_POST (
            ch_filtered_reads
        )
        ch_versions = ch_versions.mix(FASTQC_POST.out.versions.first())
    }

    //
    // SUBWORKFLOW: Uncompress and prepare reference genome files
    //
    PREPARE_GENOME ()
    ch_versions = ch_versions.mix(PREPARE_GENOME.out.versions)


    //
    // SUBWORKFLOW: Alignment with STAR or bowtie
    //

    // Align with STAR
    ch_star_multiqc      = Channel.empty()
    ch_bowtie_multiqc    = Channel.empty()
    if (params.aligner == 'star') {
        STAR_ALIGN(
            ch_filtered_reads,
            PREPARE_GENOME.out.star_index,
            PREPARE_GENOME.out.gtf,
            params.star_ignore_sjdbgtf,
            params.seq_platform,
            params.seq_center
        )
        ch_genome_bam        = STAR_ALIGN.out.bam
        ch_star_multiqc      = STAR_ALIGN.out.log_final
        ch_versions          = ch_versions.mix(STAR_ALIGN.out.versions.first())
    }

    // Align with bowtie
    else if (params.aligner == 'bowtie') {
        BOWTIE_ALIGN(
            ch_filtered_reads,
            PREPARE_GENOME.out.bowtie_index
        )
        ch_genome_bam     = BOWTIE_ALIGN.out.bam
        ch_bowtie_multiqc = BOWTIE_ALIGN.out.log
        ch_versions       = ch_versions.mix(BOWTIE_ALIGN.out.versions.first())
    }

    //
    // SUBWORKFLOW: Sort, index BAM file and run samtools stats, flagstat and idxstats
    //
    BAM_SORT_SAMTOOLS ( ch_genome_bam )
    ch_samtools_stats    = BAM_SORT_SAMTOOLS.out.stats
    ch_samtools_flagstat = BAM_SORT_SAMTOOLS.out.flagstat
    ch_samtools_idxstats = BAM_SORT_SAMTOOLS.out.idxstats
    ch_versions = ch_versions.mix(BAM_SORT_SAMTOOLS.out.versions)

    //
    // SUBWORKFLOW: Generate CTSS, make QC, BigWig files and count table
    //
    if (!params.skip_ctss_generation) {
        GENERATE_CTSS( ch_genome_bam, PREPARE_GENOME.out.chrom_sizes )
        ch_versions = ch_versions.mix(GENERATE_CTSS.out.versions)

        //
        // SUBWORKFLOW: Cluster CTSS and make count table and perform QC
        //
        if (!params.skip_ctss_clustering) {
            CLUSTER_TAGS(
                GENERATE_CTSS.out.ctss,
                PREPARE_GENOME.out.chrom_sizes,
                PREPARE_GENOME.out.gene_bed,
                params.skip_qc || params.skip_tag_cluster_qc
            )
            ch_versions = ch_versions.mix(CLUSTER_TAGS.out.versions)
        }
    }

    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
    //
    // MODULE: MultiQC
    //

    workflow_summary    = WorkflowCageseq.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(TRIMMING_PREPROCESSING.out.cutadapt_log.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_sortmerna_multiqc.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_POST.out.zip.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_star_multiqc.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_bowtie_multiqc.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_samtools_stats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_samtools_flagstat.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_samtools_idxstats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(CLUSTER_TAGS.out.tag_cluster_qc.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
//====================== end of workflow ==========================//
