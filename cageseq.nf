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
    exit 1, "The provided genome '${params.genome}' is not available in the iGenomes file. Currently the available genomes are ${params.genomes.keySet().join(", ")}"
}

params.star_index = params.genome ? params.genomes[ params.genome ].star ?: false : false
params.bowtie_index = params.genome ? params.genomes[ params.genome ].bowtie1 ?: false : false
params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false
params.gtf = params.genome ? params.genomes[ params.genome ].gtf ?: false : false

// Check mandatory parameters
if (params.input)   { ch_input = file(params.input) }   else { exit 1, 'Input not specified!'}
if (params.fasta)   { ch_fasta = file(params.fasta) }   else { exit 1, 'Genome fasta file not specified!'}
if (params.gtf)     { ch_gtf = file(params.gtf) }       else { exit 1, "No GTF annotation specified!"}

// Get rRNA databases
// Default is set to bundled DB list in `assets/rrna-db-defaults.txt`
ribo_database = file(params.ribo_database_manifest)
if (ribo_database.isEmpty()) {exit 1, "File ${ribo_database.getName()} is empty!"}
Channel
    .from( ribo_database.readLines() )
    .map { row -> file(row) }
    .set { fasta_sortmerna }

// Input validation
// Aligners and corresponding indices
// Check correct aligner
if (params.aligner != 'star' && params.aligner != 'bowtie1') {
    exit 1, "Invalid aligner option: ${params.aligner}. Valid options: 'star', 'bowtie1'"
}
// Check alignment indices
if( params.star_index && params.aligner == 'star' ){
    star_index = Channel
        .fromPath(params.star_index, checkIfExists: true)
        .ifEmpty { exit 1, "STAR index not found: ${params.star_index}" }
}
else if( params.bowtie_index && params.aligner == 'bowtie1' ){
    bowtie_index = Channel
        .fromPath(params.bowtie_index, checkIfExists: true)
        .ifEmpty { exit 1, "bowtie index not found: ${params.bowtie_index}" }
}
else if( params.fasta ) {
    ch_fasta = file(params.fasta)
}
else {
    exit 1, "No reference genome specified!"
}

// Channels for artifacts 5'-end and 3'-end
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


// Stage config files
ch_multiqc_config = file("$baseDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
ch_output_docs = file("$baseDir/docs/output.md", checkIfExists: true)
ch_output_docs_images = file("$baseDir/docs/images/", checkIfExists: true)


/////////////////////////////
/* Include process modules */
/////////////////////////////

// Define options for modules
def modules = params.modules.clone()

def fastqc_options = modules['fastqc']
def publish_genome_options = params.save_reference ? [publish_dir: 'genome'] : [publish_files: false]
def genome_options = publish_genome_options
def star_align_options = modules['star_align']
def star_genomegenerate_options = modules['star_genomegenerate']
def bowtie_align_options = modules['bowtie_align']
def bowtie_index_options = modules['bowtie_index']

// Include the modules
include { FASTQC } from                 './modules/nf-core/software/fastqc/main'                        addParams( options: fastqc_options )
include { FASTQC as FASTQC_POST }  from './modules/nf-core/software/fastqc/main'                        addParams( options: fastqc_options )
include { GET_CHROM_SIZES } from        './modules/local/process/get_chrom_sizes'                       addParams( options: publish_genome_options )
include { GTF2BED } from                './modules/local/process/gtf2bed'                               addParams( options: genome_options )
include { GET_SOFTWARE_VERSIONS } from  './modules/local/process/get_software_versions'                 addParams( options: [:] )
include { SORTMERNA } from              './modules/local/process/sortmerna'                             addParams( options: [:] )
include { MULTIQC } from                './modules/local/process/multiqc'                               addParams( options: [:] )

// Include subworkflows
include { INPUT_CHECK }             from './modules/local/subworkflow/input_check'                      addParams( options: [:] )
include { TRIMMING_PREPROCESSING }  from './modules/local/subworkflow/trimming'                         addParams( options: [:] )
include { ALIGN_STAR }              from './modules/local/subworkflow/align_star'                       addParams( align_options: star_align_options, index_options: star_genomegenerate_options)
include { ALIGN_BOWTIE }            from './modules/local/subworkflow/align_bowtie'                     addParams( align_options: bowtie_align_options, index_options: bowtie_index_options)
include { CTSS_GENERATION }         from './modules/local/subworkflow/ctss_generation'                  addParams( options: [:] )






//=====================================================//
/* CAGE-seq workflow */
//=====================================================//

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

    // Convert GTF to Bed format
    GTF2BED( ch_gtf )

    // Get chromosome sizes
    GET_CHROM_SIZES( ch_fasta )
    
    // Trim adapters
    TRIMMING_PREPROCESSING( 
        ch_fastq,
        ch_5end_artifacts,
        ch_3end_artifacts
        )
    
    ch_reads = TRIMMING_PREPROCESSING.out.reads
    
    // Removal ribosomal RNA
    ch_sortmerna_multiqc = Channel.empty()
    if (params.remove_ribo_rna) {
        SORTMERNA( ch_reads, fasta_sortmerna )
        ch_reads = SORTMERNA.out.reads
        ch_sortmerna_multiqc = SORTMERNA.out.log
    }

    // Optional post-preprocessing QC
    if(!params.skip_trimming_fastqc && !params.skip_trimming){
        FASTQC_POST( ch_reads )
    }
    
    // Align with STAR
    if (params.aligner == 'star'){
        ALIGN_STAR(
            ch_reads,
            params.star_index,
            ch_fasta,
            ch_gtf
            )
        ch_bam = ALIGN_STAR.out.bam
    }
    // Align with bowtie1
    else if (params.aligner == 'bowtie1'){
        ALIGN_BOWTIE(
            ch_reads,
            params.bowtie_index,
            ch_fasta,
            ch_gtf
        )
        ch_bam = ALIGN_BOWTIE.out.bam
    }

    // Generate CTSS, make QC, BigWig files and count table
    if (!params.skip_ctss_generation){
        CTSS_GENERATION(
            ch_bam,
            GET_CHROM_SIZES.out.sizes,
            GTF2BED.out
        )
    }

    // Get software versions
    ch_software_versions = Channel.empty()
    ch_software_versions = ch_software_versions.mix(FASTQC.out.version.first().ifEmpty(null))
    //ch_software_versions = ch_software_versions.mix(SORTMERNA.out.version.first().ifEmpty(null))
    GET_SOFTWARE_VERSIONS ( ch_software_versions.map { it }.collect())

    // MultiQC
    MULTIQC(
        GET_SOFTWARE_VERSIONS.out.yaml.collect(),
        FASTQC.out.zip.collect{it[1]}.ifEmpty([])

    )

}
//====================== end of workflow ==========================//