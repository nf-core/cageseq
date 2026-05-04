/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// workflow utils
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_cageseq_pipeline'
include { softwareVersionsToYAML    } from '../subworkflows/nf-core/utils_nfcore_pipeline'

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
include { BAM_STATS_SAMTOOLS } from '../subworkflows/nf-core/bam_stats_samtools/main'
include { MULTIQC } from '../modules/nf-core/multiqc/main.nf'
include { WRITE_SAMPLE_LIST } from '../modules/local/write_sample_list/main.nf'
include { CAGER } from '../subworkflows/local/cager/main.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CAGESEQ {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()

    ch_gtf = channel.fromPath(params.gtf, checkIfExists: true)

    if (!params.maponly && !params.fullpipeline){
        if (!params.cager_sample_file ) {
            exit 1, 'Sample list file is mandatory if mapping is not done within the pipeline.'
        }
        println("Running CAGEr analysis subpipeline")

        ch_cager_sample_file = channel.fromPath(params.cager_sample_file)
        mapped_files_ch = MAPPED_INPUTS(ch_cager_sample_file).collect()
        merged_sample_file = RELATIVISATION(ch_cager_sample_file)

    }

    if (params.maponly || params.fullpipeline) {

        ch_fasta = channel.empty()
        ch_index = channel.empty()

        PARAMETER_CHECKS(ch_fasta, ch_index)

        ch_fasta = PARAMETER_CHECKS.out.ch_fasta
        ch_index = PARAMETER_CHECKS.out.ch_index
        ch_fastq = PARAMETER_CHECKS.out.ch_fastq

        PREPROCESSING(ch_fastq, ch_multiqc_files)

        ch_reads_to_align = PREPROCESSING.out.ch_reads_to_align
        ch_multiqc_files = PREPROCESSING.out.ch_multiqc_files

        PREPARE_MAPPING_METADATA( ch_fasta )
        ch_chrom_sizes = PREPARE_MAPPING_METADATA.out.ch_chrom_sizes
        ch_fasta = PREPARE_MAPPING_METADATA.out.ch_fasta

        if (params.bowtie2) {
            BOWTIE2(ch_reads_to_align, ch_fasta, ch_index, ch_multiqc_files)

            ch_aligned = BOWTIE2.out.ch_aligned
            ch_multiqc_files = BOWTIE2.out.ch_multiqc_files
            // NOTE: placeholder so that the channel is not empty
            // it will be replaced in SAMTOOLS
            ch_for_cager = ch_aligned

        } else {
            STAR(ch_reads_to_align, ch_fasta, ch_index, ch_gtf, ch_chrom_sizes, ch_multiqc_files)

            ch_for_cager = STAR.out.bigwig_ch_for_cager
            ch_aligned = STAR.out.ch_aligned
            ch_multiqc_files = STAR.out.ch_multiqc_files
        }

        if (params.dedup) {
            DEDUPLICATION(ch_aligned, ch_for_cager)

            ch_for_cager = DEDUPLICATION.out.ch_for_cager
            ch_bam_bai = DEDUPLICATION.out.ch_bam_bai
        } else {
            SAMTOOLS_PROCESSING(ch_aligned, ch_fasta, ch_for_cager)

            ch_for_cager = SAMTOOLS_PROCESSING.out.ch_for_cager
            ch_bam_bai = SAMTOOLS_PROCESSING.out.ch_bam_bai
        }

        ch_meta_fasta = ch_bam_bai
            .combine(ch_fasta)
            .map{[it[3], it[4]]}

        BAM_STATS_SAMTOOLS(ch_bam_bai, ch_meta_fasta)

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

        PREPARE_CAGER_METADATA( ch_gtf )
        ch_bsgenome_file = PREPARE_CAGER_METADATA.out.ch_bsgenome_file
        ch_bsgenome_name = PREPARE_CAGER_METADATA.out.ch_bsgenome_name
        ch_txdb_file = PREPARE_CAGER_METADATA.out.ch_txdb_file

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
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'cageseq_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'cageseq'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
