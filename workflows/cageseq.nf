/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Workflow utils
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_cageseq_pipeline/main'
include { getGenomeAttribute        } from '../subworkflows/local/utils_nfcore_cageseq_pipeline/main'

// Input readers
include { MAPPED_INPUTS             } from '../subworkflows/local/mapped_inputs/main.nf'
include { RELATIVISATION            } from '../modules/local/relativisation/main.nf'

// Pipeline subworkflows and modules
include { PREPROCESSING             } from '../subworkflows/local/preprocessing/main.nf'
include { PREPARE_MAPPING_METADATA  } from '../subworkflows/local/prepare_mapping_metadata/main.nf'
include { PREPARE_CAGER_METADATA    } from '../subworkflows/local/prepare_cager_metadata/main.nf'
include { STAR                      } from '../subworkflows/local/star/main.nf'
include { BOWTIE2                   } from '../subworkflows/local/bowtie2/main.nf'
include { DEDUPLICATION             } from '../subworkflows/local/deduplication/main.nf'
include { SAMTOOLS_PROCESSING       } from '../subworkflows/local/samtools/main.nf'
include { BAM_STATS_SAMTOOLS        } from '../subworkflows/nf-core/bam_stats_samtools/main'
include { WRITE_SAMPLE_LIST         } from '../modules/local/write_sample_list/main.nf'
include { CAGER                     } from '../subworkflows/local/cager/main.nf'

// Core nf-core modules
include { FASTQC                    } from '../modules/nf-core/fastqc/main'
include { MULTIQC                   } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CAGESEQ {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()

    //
    // Check GTF parameter
    //

    ch_gtf = channel.fromPath(params.gtf, checkIfExists: true)

    //
    // Handle CAGEr-only mode (no mapping)
    //
    if (!params.maponly && !params.fullpipeline) {
        ch_cager_sample_file = channel.fromPath(params.cager_sample_file)
        mapped_files_ch = MAPPED_INPUTS(ch_cager_sample_file).collect()
        merged_sample_file = RELATIVISATION(ch_cager_sample_file)
    }

    //
    // Mapping workflow (maponly or fullpipeline modes)
    //
    if (params.maponly || params.fullpipeline) {

        //
        // Use reads channel from pipeline initialisation
        //
        ch_fastq = ch_samplesheet

        //
        // Create genome and index channels from parameters
        //
        ch_genome_name = channel.of(params.genome_name)
        if (params.index) {
            ch_pre_idx = channel.fromPath(params.index, checkIfExists: true)
            sample_meta = ch_fastq.map { meta, fastq -> [meta] }
            ch_index = sample_meta.combine(ch_pre_idx)
            if (params.genome) {
                ch_pre_fa = channel.fromPath(params.genome, checkIfExists: true)
                ch_fasta = ch_genome_name.combine(ch_pre_fa)
            } else {
                ch_fasta = channel.empty()
            }
        } else if (params.genome) {
            def fasta_igenomes = getGenomeAttribute('fasta')
            def index_igenomes = params.bowtie2 ? getGenomeAttribute('bowtie2') : getGenomeAttribute('star')
            if (fasta_igenomes) {
                ch_pre_fa = channel.fromPath(fasta_igenomes, checkIfExists: true)
                ch_fasta  = ch_genome_name.combine(ch_pre_fa)
            } else {
                ch_fasta = channel.empty()
            }
            if (index_igenomes) {
                ch_pre_idx  = channel.fromPath(index_igenomes, checkIfExists: true)
                sample_meta = ch_fastq.map { meta, fastq -> [meta] }
                ch_index    = sample_meta.combine(ch_pre_idx)
            } else {
                ch_index = channel.empty()
            }
        } else {
            ch_pre_fa = channel.fromPath(params.genome, checkIfExists: true)
            ch_fasta = ch_genome_name.combine(ch_pre_fa)
            ch_index = channel.empty()
        }

        //
        // MODULE: Run FastQC on raw reads
        //
        FASTQC(ch_fastq)
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect { it[1] })
        ch_versions = ch_versions.mix(FASTQC.out.versions.first())

        //
        // SUBWORKFLOW: Preprocessing (trimming, filtering, etc.)
        //
        PREPROCESSING(ch_fastq, ch_multiqc_files)

        ch_reads_to_align = PREPROCESSING.out.ch_reads_to_align
        ch_multiqc_files = PREPROCESSING.out.ch_multiqc_files

        //
        // SUBWORKFLOW: Prepare mapping metadata
        //
        PREPARE_MAPPING_METADATA(ch_fasta)
        ch_chrom_sizes = PREPARE_MAPPING_METADATA.out.ch_chrom_sizes
        ch_fasta = PREPARE_MAPPING_METADATA.out.ch_fasta

        //
        // SUBWORKFLOW: Alignment (Bowtie2 or STAR)
        //
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

        //
        // SUBWORKFLOW: Deduplication or SAMtools processing
        //
        if (params.dedup) {
            DEDUPLICATION(ch_aligned, ch_for_cager, ch_fasta)

            ch_for_cager = DEDUPLICATION.out.ch_for_cager
            ch_bam_bai = DEDUPLICATION.out.ch_bam_bai
        } else {
            SAMTOOLS_PROCESSING(ch_aligned, ch_fasta, ch_for_cager)

            ch_for_cager = SAMTOOLS_PROCESSING.out.ch_for_cager
            ch_bam_bai = SAMTOOLS_PROCESSING.out.ch_bam_bai
        }

        //
        // SUBWORKFLOW: BAM statistics
        //
        ch_meta_fasta = ch_bam_bai
            .combine(ch_fasta)
            .map { tuple -> [tuple[3], tuple[4]] }

        BAM_STATS_SAMTOOLS(ch_bam_bai, ch_meta_fasta)

        //
        // Collect mapped files for CAGEr
        //
        if (params.bowtie2) {
            mapped_files_ch = ch_for_cager
                .map { meta, paths -> [paths] }
                .collect()
        } else {
            mapped_files_ch = ch_for_cager
                .map { meta, paths ->
                    def file1 = paths[0]
                    def file2 = paths[1]
                    [file1, file2]
                }
                .collect()
        }

        //
        // MODULE: Write sample list for CAGEr
        //
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

        //
        // SUBWORKFLOW: CAGEr analysis
        //
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

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'cageseq_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
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

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
