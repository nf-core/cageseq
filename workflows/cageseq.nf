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
 * SET UP CONFIGURATION VARIABLES
 */

// Check if genome exists in the config file
if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
    exit 1, "The provided genome '${params.genome}' is not available in the iGenomes file. Currently the available genomes are ${params.genomes.keySet().join(', ')}"
}

params.star_index = params.genome ? params.genomes[ params.genome ].star ?: false : false
params.bowtie_index = params.genome ? params.genomes[ params.genome ].bowtie1 ?: false : false
params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false
params.gtf = params.genome ? params.genomes[ params.genome ].gtf ?: false : false

// Check mandatory parameters
if (params.input)   { ch_input = file(params.input) }   else { exit 1, 'Input not specified!' }
if (params.fasta)   { ch_fasta = file(params.fasta) }   else { exit 1, 'Genome fasta file not specified!' }
if (params.gtf)     { ch_gtf = file(params.gtf) }       else { exit 1, 'No GTF annotation specified!' }

if (params.remove_ribo_rna) {
    // Get rRNA databases
    // Default is set to bundled DB list in `assets/rrna-db-defaults.txt`
    ribo_database = file(params.ribo_database_manifest)
    if (ribo_database.isEmpty()) { exit 1, "File ${ribo_database.getName() } is empty!" }
    Channel
        .from( ribo_database.readLines() )
        .map { row -> file(row) }
        .set { fasta_sortmerna }
}

// Input validation
// Aligners and corresponding indices
// Check correct aligner
if (params.aligner != 'star' && params.aligner != 'bowtie1') {
    exit 1, "Invalid aligner option: ${params.aligner}. Valid options: 'star', 'bowtie1'"
}
// Check alignment indices
if ( params.star_index && params.aligner == 'star' ) {
    star_index = Channel
        .fromPath(params.star_index, checkIfExists: true)
        .ifEmpty { exit 1, "STAR index not found: ${params.star_index}" }
}
else if ( params.bowtie_index && params.aligner == 'bowtie1' ) {
    bowtie_index = Channel
        .fromPath(params.bowtie_index, checkIfExists: true)
        .ifEmpty { exit 1, "bowtie index not found: ${params.bowtie_index}" }
}
else if ( params.fasta ) {
    ch_fasta = file(params.fasta)
}
else {
    exit 1, 'No reference genome specified!'
}

// Channels for artifacts 5'-end and 3'-end
if ( params.artifacts_5end ) {
    ch_5end_artifacts = Channel
        .fromPath(params.artifacts_5end)
}
else {
    ch_5end_artifacts = Channel
        .fromPath("$baseDir/assets/artifacts_5end.fasta")
}

if ( params.artifacts_3end ) {
    ch_3end_artifacts = Channel
        .fromPath(params.artifacts_3end)
}
else {
    ch_3end_artifacts = Channel
        .fromPath("$baseDir/assets/artifacts_3end.fasta")
}

// Stage config files
ch_multiqc_config = Channel.fromPath("$baseDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
ch_output_docs = file("$baseDir/docs/output.md", checkIfExists: true)
ch_output_docs_images = file("$baseDir/docs/images/", checkIfExists: true)

/////////////////////////////
/* Include process modules */
/////////////////////////////

// Define options for modules
def modules = params.modules.clone()

def fastqc_options = modules['fastqc']
def fastqc_post_options = modules['fastqc_post']
def publish_genome_options = params.save_reference ? [publish_dir: 'genome'] : [publish_files: false]
def genome_options = publish_genome_options
def star_align_options = modules['star_align']
def star_genomegenerate_options = modules['star_genomegenerate']
def bowtie_align_options = modules['bowtie_align']
def bowtie_index_options = modules['bowtie_index']
def sortmerna_options = modules['sortmerna']

// Include the modules
include { FASTQC }                      from '../modules/nf-core/software/fastqc/main'                   addParams( options: fastqc_options )
include { FASTQC as FASTQC_POST }       from '../modules/nf-core/software/fastqc/main'                   addParams( options: fastqc_post_options )
include { GET_CHROM_SIZES }             from '../modules/local/get_chrom_sizes'                          addParams( options: publish_genome_options )
include { GTF2BED }                     from '../modules/local/gtf2bed'                                  addParams( options: genome_options )
include { GET_SOFTWARE_VERSIONS }       from '../modules/local/get_software_versions'                    addParams( options: [:] )
include { SORTMERNA }                   from '../modules/local/sortmerna'                                addParams( options: sortmerna_options )
include { MULTIQC }                     from '../modules/local/multiqc'                                  addParams( options: [:] )
include { MULTIQC_CUSTOM_FAIL_MAPPED }  from '../modules/local/multiqc_custom_fail_mapped'               addParams( options: [publish_files: false] )

// Include subworkflows
include { INPUT_CHECK }                 from '../subworkflows/local/input_check'                          addParams( options: [:] )
include { TRIMMING_PREPROCESSING }      from '../subworkflows/local/trimming'                             addParams( options: [:] )
include { ALIGN_STAR }                  from '../subworkflows/local/align_star'                           addParams( align_options: star_align_options, index_options: star_genomegenerate_options)
include { ALIGN_BOWTIE }                from '../subworkflows/local/align_bowtie'                         addParams( align_options: bowtie_align_options, index_options: bowtie_index_options)
include { CTSS_GENERATION }             from '../subworkflows/local/ctss_generation'                      addParams( options: [:] )

//=====================================================//
/* CAGE-seq workflow */
//=====================================================//

// Info required for completion email and summary
def multiqc_report      = []
def pass_percent_mapped = [:]
def fail_percent_mapped = [:]
params.summary_params = [:]

workflow CAGESEQ {
    /*
     * SUBWORKFLOW: Read in samplesheet, validate and stage input files
    */
    INPUT_CHECK( ch_input )
    .map {
        meta, bam -> meta.id = meta.id.split('_')[0..-2].join('_')
        [ meta, bam ]
    }
    .groupTuple(by: [0])
    .map { it -> [ it[0], it[1].flatten() ] }
    .set { ch_fastq }

    // FASTQC
    FASTQC( ch_fastq )
    fastqc_html = FASTQC.out.html
    fastqc_zip = FASTQC.out.zip
    fastqc_version = FASTQC.out.version

    // Channel for software version
    ch_software_versions = Channel.empty()
    ch_software_versions = ch_software_versions.mix(FASTQC.out.version.first().ifEmpty(null))

    // Convert GTF to Bed format
    GTF2BED( ch_gtf )

    // Get chromosome sizes
    GET_CHROM_SIZES( ch_fasta )

    // Trim adapters
    ch_cutadapt_multiqc = Channel.empty()
    TRIMMING_PREPROCESSING(
        ch_fastq,
        ch_5end_artifacts,
        ch_3end_artifacts
        )
    if (!params.skip_trimming) {
        ch_software_versions = ch_software_versions.mix(TRIMMING_PREPROCESSING.out.cutadapt_version.first().ifEmpty(null))
        ch_cutadapt_multiqc = TRIMMING_PREPROCESSING.out.cutadapt_log
    }

    ch_reads = TRIMMING_PREPROCESSING.out.reads

    // Removal ribosomal RNA
    ch_sortmerna_multiqc = Channel.empty()
    if (params.remove_ribo_rna) {
        SORTMERNA( ch_reads, fasta_sortmerna )

        ch_reads = SORTMERNA.out.reads
        ch_sortmerna_multiqc = SORTMERNA.out.log
        ch_software_versions = ch_software_versions.mix(SORTMERNA.out.version.first().ifEmpty(null))
    }

    // Optional post-preprocessing QC
    ch_fastqc_post_multiqc = Channel.empty()
    if (!params.skip_trimming_fastqc && !params.skip_trimming) {
        FASTQC_POST( ch_reads )
        ch_fastqc_post_multiqc = FASTQC_POST.out.zip
    }

    // Align with STAR
    ch_samtools_stats    = Channel.empty()
    ch_samtools_flagstat = Channel.empty()
    ch_samtools_idxstats = Channel.empty()
    ch_star_multiqc      = Channel.empty()
    ch_bowtie_multiqc    = Channel.empty()
    if (params.aligner == 'star') {
        ALIGN_STAR(
            ch_reads,
            params.star_index,
            ch_fasta,
            ch_gtf
            )
        ch_genome_bam        = ALIGN_STAR.out.bam
        ch_genome_bai        = ALIGN_STAR.out.bai
        ch_samtools_stats    = ALIGN_STAR.out.stats
        ch_samtools_flagstat = ALIGN_STAR.out.flagstat
        ch_samtools_idxstats = ALIGN_STAR.out.idxstats
        ch_star_multiqc      = ALIGN_STAR.out.log_final
        ch_software_versions = ch_software_versions.mix(ALIGN_STAR.out.star_version.first().ifEmpty(null))
        ch_software_versions = ch_software_versions.mix(ALIGN_STAR.out.samtools_version.first().ifEmpty(null))
    }
    // Align with bowtie1
    else if (params.aligner == 'bowtie1') {
        ALIGN_BOWTIE(
            ch_reads,
            params.bowtie_index,
            ch_fasta,
            ch_gtf
        )
        ch_genome_bam           = ALIGN_BOWTIE.out.bam
        ch_genome_bai           = ALIGN_BOWTIE.out.bai
        ch_samtools_stats       = ALIGN_BOWTIE.out.stats
        ch_samtools_flagstat    = ALIGN_BOWTIE.out.flagstat
        ch_samtools_idxstats    = ALIGN_BOWTIE.out.idxstats
        ch_software_versions = ch_software_versions.mix(ALIGN_BOWTIE.out.bowtie_version.first().ifEmpty(null))
        ch_software_versions = ch_software_versions.mix(ALIGN_BOWTIE.out.samtools_version.first().ifEmpty(null))
        ch_bowtie_multiqc = ALIGN_BOWTIE.out.log_out
    }

       /*
     * Filter channels to get samples that passed STAR/Bowtie1 minimum mapping percentage
     */
    ch_fail_mapping_multiqc = Channel.empty()
    if (!params.skip_alignment) {
        if (params.aligner == 'star') {
            ch_star_multiqc
                .map { meta, align_log -> [ meta ] + Checks.get_star_percent_mapped(workflow, params, log, align_log) }
                .set { ch_percent_mapped }
        }
        if (params.aligner == 'bowtie1') {
            ch_bowtie_multiqc
                .map { meta, align_log -> [ meta ] + Checks.get_bowtie_percent_mapped(workflow, params, log, align_log) }
                .set { ch_percent_mapped }
        }

        ch_genome_bam
            .join(ch_percent_mapped, by: [0])
            .map { meta, ofile, mapped, pass -> if (pass) [ meta, ofile ] }
            .set { ch_genome_bam }

        ch_genome_bai
            .join(ch_percent_mapped, by: [0])
            .map { meta, ofile, mapped, pass -> if (pass) [ meta, ofile ] }
            .set { ch_genome_bai }

        ch_percent_mapped
            .branch { meta, mapped, pass ->
                pass: pass
                    pass_percent_mapped[meta.id] = mapped
                    return [ "$meta.id\t$mapped" ]
                fail: !pass
                    fail_percent_mapped[meta.id] = mapped
                    return [ "$meta.id\t$mapped" ]
            }
            .set { ch_pass_fail_mapped }

        MULTIQC_CUSTOM_FAIL_MAPPED (
            ch_pass_fail_mapped.fail.collect()
        )
        .set { ch_fail_mapping_multiqc }
    }

    // Generate CTSS, make QC, BigWig files and count table
    ch_ctss_multiqc = Channel.empty()
    if (!params.skip_ctss_generation) {
        CTSS_GENERATION(
            ch_genome_bam,
            GET_CHROM_SIZES.out.sizes,
            GTF2BED.out
        )
        ch_ctss_multiqc = CTSS_GENERATION.out.ctss_qc
    }

    // Get software versions
    GET_SOFTWARE_VERSIONS ( ch_software_versions.map { it }.collect())

    // MultiQC
    MULTIQC(
        ch_multiqc_config,
        GET_SOFTWARE_VERSIONS.out.yaml.collect(),
        FASTQC.out.zip.collect { it[1] }.ifEmpty([]),
        ch_cutadapt_multiqc.collect { it[1] }.ifEmpty([]),
        ch_sortmerna_multiqc.collect { it[1] }.ifEmpty([]),
        ch_fastqc_post_multiqc.collect { it[1] }.ifEmpty([]),
        ch_star_multiqc.collect { it[1] }.ifEmpty([]),
        ch_bowtie_multiqc.collect { it[1] }.ifEmpty([]),
        ch_fail_mapping_multiqc.ifEmpty([]),
        ch_ctss_multiqc.collect { it[1] }.ifEmpty([]),
        ch_samtools_stats.collect { it[1] }.ifEmpty([]),
        ch_samtools_flagstat.collect { it[1] }.ifEmpty([]),
        ch_samtools_idxstats.collect { it[1] }.ifEmpty([])
    )

    multiqc_report = MULTIQC.out.report.toList()
}

////////////////////////////////////////////////////
/* --              COMPLETION EMAIL            -- */
////////////////////////////////////////////////////

workflow.onComplete {
    Completion.email(workflow, params, params.summary_params, baseDir, log, multiqc_report, fail_percent_mapped)
    Completion.summary(workflow, params, log, fail_percent_mapped, pass_percent_mapped)
}
//====================== end of workflow ==========================//
