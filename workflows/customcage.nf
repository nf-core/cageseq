// pipeline run settings
params.fullpipeline = true
params.maponly = false
params.cageronly = false

// genome annotation in GTF
params.gtf = "$projectDir/assets/NO_FILE_GTF"

// preprocessing parameters
params.input = "$projectDir/assets/NO_FILE_SAMPLESHEET"
params.infolder = ''
params.outdir = "results"
params.sample_name_fields = ''
params.genome_name = ''
params.fasta = "$projectDir/assets/NO_FILE_FASTA"
params.index = "$projectDir/assets/NO_FILE_INDEX"
params.seq_platform = ''
params.seq_center = false
params.unique_only = true
params.remove_non_g = false

// TrimGalore! parameters
params.params_trimgalore = '-v'

// cutadapt parameters
params.nogtrim = false

// read deduplication parameters
params.dedup = false
params.dist = false

// bowtie2 parameters
params.bowtie2 = false

// CAGEr markdown template location
params.markdown_path = "$projectDir/assets/cager_report.Rmd"

// BSgenome parameters
params.bsgenome = false
params.forgeseed = "$projectDir/assets/NO_FILE_FORGESEED"
params.sourcedir = ''

// CAGEr parameters
params.cager_sample_file = "$projectDir/assets/NO_FILE_CAGERSAMPLESHEET"
params.datatype = "bigwig"
// parameter for correlation calculation
params.corrplot_tagCountThreshold = 1
// parameters for normalization
params.norm_range_min = 5
params.norm_range_max = 10000
params.norm_method = "powerLaw"
params.alpha = false
params.t_norm = 1000000
// parameters for tag clustering
params.sample_num_thr = 1
params.ctss_thr = 1
params.distclu_maxDist = 20
params.keepSingletonsAbove = 5
params.iq_low = 0.1
params.iq_high = 0.9
// plotting for tagclusters QC
params.iqw_tpm_threshold = 3
params.tssregion_up = -3000
params.tssregion_down = 3000
params.tsslogo_upstream = 35
// parameters for consensus clusters
params.consensus_thr = 2
params.consensus_dist = 100
// parameters for enhancer calling
params.cfBalanceThreshold = 0.95
params.unexpressed = 0
params.minSamples = 0

// workflow utils
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_customcage_pipeline'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'

// input readers
include { MAPPED_INPUTS } from "../subworkflows/local/mapped_inputs/main.nf"
include { RELATIVISATION } from '../modules/local/relativisation/main.nf'

// pipeline subworkflows and modules
include { PARAMETER_CHECKS } from '../subworkflows/local/parameter_checks/main.nf'
include { PREPROCESSING } from '../subworkflows/local/preprocessing/main.nf'
include { PREPARE_MAPPING_METADATA } from '../subworkflows/local/prepare_mapping_metadata/main.nf'
include { PREPARE_CAGER_METADATA } from '../subworkflows/local/prepare_cager_metadata/main.nf'
include { STAR } from '../subworkflows/local/star/main.nf'
include { BOWTIE2 } from '../subworkflows/local/bowtie2/main.nf'
include { DEDUPLICATION } from '../subworkflows/local/deduplication/main.nf'
include { SAMTOOLS_PROCESSING } from '../subworkflows/local/samtools/main.nf'
include { SAMTOOLS_STATISTICS } from '../subworkflows/local/samtools_statistics/main.nf'
include { MULTIQC } from '../modules/nf-core/multiqc/main.nf'
include { WRITE_SAMPLE_LIST } from '../modules/local/write_sample_list/main.nf'
include { CAGER } from '../subworkflows/local/cager/main.nf'

def multiqc_report = []

workflow CUSTOMCAGE {

    take:
    ch_versions

    main:

    if (params.gtf) {
            ch_gtf = Channel.fromPath(params.gtf, checkIfExists: true)
        } else {
            exit 1, "The --gtf argument is mandatory."
    }

    if (!params.maponly && !params.fullpipeline){
        if (!params.cager_sample_file ) {
            exit 1, 'Sample list file is mandatory if mapping is not done within the pipeline.'
        }
        println("Running CAGEr analysis subpipeline")

        ch_cager_sample_file = Channel.fromPath(params.cager_sample_file)
        mapped_files_ch = MAPPED_INPUTS(ch_cager_sample_file).collect()
        merged_sample_file = RELATIVISATION(ch_cager_sample_file)

    }

    ch_multiqc_files = Channel.empty()

    if (params.maponly || params.fullpipeline) {

        ch_fasta = Channel.empty()
        ch_index = Channel.empty()

        PARAMETER_CHECKS(ch_fasta, ch_index, ch_versions)

        ch_fasta = PARAMETER_CHECKS.out.ch_fasta
        ch_index = PARAMETER_CHECKS.out.ch_index
        ch_fastq = PARAMETER_CHECKS.out.ch_fastq
        ch_versions = PARAMETER_CHECKS.out.ch_versions

        PREPROCESSING(ch_fastq, ch_versions, ch_multiqc_files)

        ch_reads_to_align = PREPROCESSING.out.ch_reads_to_align
        ch_multiqc_files = PREPROCESSING.out.ch_multiqc_files
        ch_versions = PREPROCESSING.out.ch_versions

        PREPARE_MAPPING_METADATA( ch_fasta, ch_versions )
        ch_chrom_sizes = PREPARE_MAPPING_METADATA.out.ch_chrom_sizes
        ch_fasta = PREPARE_MAPPING_METADATA.out.ch_fasta
        ch_versions = PREPARE_MAPPING_METADATA.out.ch_versions

        if (params.bowtie2) {
            BOWTIE2(ch_reads_to_align, ch_fasta, ch_index, ch_multiqc_files, ch_versions)

            ch_aligned = BOWTIE2.out.ch_aligned
            ch_multiqc_files = BOWTIE2.out.ch_multiqc_files
            ch_versions = BOWTIE2.out.ch_versions
            // NOTE: placeholder so that the channel is not empty
            // it will be replaced in SAMTOOLS
            ch_for_cager = ch_aligned

        } else {
            STAR(ch_reads_to_align, ch_fasta, ch_index, ch_gtf, ch_chrom_sizes, ch_multiqc_files, ch_versions)

            ch_for_cager = STAR.out.bigwig_ch_for_cager
            ch_aligned = STAR.out.ch_aligned
            ch_multiqc_files = STAR.out.ch_multiqc_files
            ch_versions = STAR.out.ch_versions
        }

        if (params.dedup) {
            DEDUPLICATION(ch_aligned, ch_versions, ch_for_cager)

            ch_for_cager = DEDUPLICATION.out.ch_for_cager
            ch_bam_bai = DEDUPLICATION.out.ch_bam_bai
            ch_versions = DEDUPLICATION.out.ch_versions
        } else {
            SAMTOOLS_PROCESSING(ch_aligned, ch_versions, ch_for_cager)

            ch_for_cager = SAMTOOLS_PROCESSING.out.ch_for_cager
            ch_bam_bai = SAMTOOLS_PROCESSING.out.ch_bam_bai
            ch_versions = SAMTOOLS_PROCESSING.out.ch_versions
        }

        SAMTOOLS_STATISTICS(ch_bam_bai, ch_fasta, ch_multiqc_files, ch_versions)

        ch_multiqc_files = SAMTOOLS_STATISTICS.out.ch_multiqc_files
        ch_versions = SAMTOOLS_STATISTICS.out.ch_versions

        if (params.bowtie2) {
            mapped_files_ch = ch_for_cager.map{ meta, paths ->
                [paths]}
                .collect()
        } else {
            mapped_files_ch = ch_for_cager.map{ meta, paths ->
                file1 = paths[0]
                file2 = paths[1]
                [file1, file2]}
                .collect()
        }


        ch_sample_files = WRITE_SAMPLE_LIST(ch_for_cager)
        def header = "id,single_end,path,new_name"

        ch_collected = ch_sample_files
        .reduce( header ) { acc, table_line ->
            acc + '\n' + table_line.readLines()[0]}

        // sorting samples alphabetically
        merged_sample_file = ch_collected.collectFile(
            name: "sample_list.csv",
            newLine: true,
            sort: { file -> file.text })

    }

    if (params.cageronly || params.fullpipeline) {

        PREPARE_CAGER_METADATA( ch_gtf, ch_versions )
        ch_bsgenome_file = PREPARE_CAGER_METADATA.out.ch_bsgenome_file
        ch_bsgenome_name = PREPARE_CAGER_METADATA.out.ch_bsgenome_name
        ch_txdb_file = PREPARE_CAGER_METADATA.out.ch_txdb_file
        ch_versions = PREPARE_CAGER_METADATA.out.ch_versions

        CAGER(
            ch_bsgenome_file,
            ch_bsgenome_name,
            merged_sample_file,
            mapped_files_ch,
            ch_txdb_file,
            ch_versions
        )

        ch_versions = CAGER.out.ch_versions

    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'customcage_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
