// All parameter defaults are defined in nextflow.config (params block). Nextflow
// applies config values over script-level `params.x = ...` assignments, so defaults
// declared here would be dead code; the schema (nextflow_schema.json) must match the
// config and is checked by `nf-core pipelines schema lint`.

// workflow utils
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_cageseq_pipeline'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'

// input readers
include { MAPPED_INPUTS } from "../subworkflows/local/mapped_inputs/main.nf"
include { RELATIVISATION } from '../modules/local/relativisation/main.nf'

// pipeline subworkflows and modules
include { PARAMETER_CHECKS } from '../subworkflows/local/parameter_checks/main.nf'
include { amendSampleNames; fixSampleName } from '../subworkflows/local/sample_names/main.nf'
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

def multiqc_report = []

workflow CAGESEQ {

    take:
    ch_versions

    main:

    if (params.gtf) {
            ch_gtf = Channel.fromPath(params.gtf, checkIfExists: true)
        } else {
            exit 1, "The --gtf argument is mandatory."
    }

    // --cager_sample_file only makes sense when the pipeline does not map the reads
    // itself: in the fullpipeline and maponly modes the CAGEr sample list is generated
    // from the mapping results, so a user-provided one would be silently ignored.
    if ((params.maponly || params.fullpipeline) && params.cager_sample_file) {
        exit 1, "The --cager_sample_file option is only valid in the cageronly mode " +
            "(--cageronly true --fullpipeline false). In the fullpipeline and maponly modes " +
            "the pipeline generates the CAGEr sample list itself from the mapping results " +
            "(<outdir>/cager_sample_list/cager_sample_list.csv). Please remove " +
            "--cager_sample_file (currently '${params.cager_sample_file}') or switch to the cageronly mode."
    }

    if (!params.maponly && !params.fullpipeline){
        if (!params.cager_sample_file ) {
            exit 1, 'Sample list file is mandatory if mapping is not done within the pipeline.'
        }

        // Amend the sample names of the user's list ('id' and 'new_name' columns)
        // where needed, warning once per amended name, and hand the amended list
        // to the CAGEr part. Done synchronously, before any task starts.
        def list_file = file(params.cager_sample_file, checkIfExists: true)
        def list_header = list_file.readLines().find { line -> line.trim() }.split(',').collect { col -> col.trim() }
        def list_rows = list_file.splitCsv(header: true, sep: ',')
        def list_name_map = amendSampleNames(
            (list_rows.collect { row -> row.id?.trim() } + list_rows.collect { row -> row.new_name?.trim() }).findAll { n -> n },
            "CAGEr sample list '${params.cager_sample_file}' (columns 'id' and 'new_name')")
        def amended_lines = list_rows.collect { row ->
            list_header.collect { col ->
                def value = row[col]
                (col in ['id', 'new_name'] && value?.trim()) ? list_name_map.get(value.trim(), value.trim()) : value
            }.join(',')
        }
        ch_cager_sample_file = Channel.of(([list_header.join(',')] + amended_lines).join('\n'))
            .collectFile(name: "cager_sample_list_amended.csv", newLine: true, sort: false)
        mapped_files_ch = MAPPED_INPUTS(ch_cager_sample_file).collect()
        merged_sample_file = RELATIVISATION(ch_cager_sample_file)

    }

    ch_multiqc_files = Channel.empty()

    if (params.maponly || params.fullpipeline) {

        ch_fasta = Channel.empty()
        ch_index = Channel.empty()

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

        // The samtools steps below (sort/index/dedup and stats/flagstat/idxstats)
        // only use the FASTA as an optional `--reference`, which they don't
        // actually need: their core output is identical without it. When no FASTA
        // is available (i.e. only --index was given), ch_fasta is an empty channel,
        // which would silently gate these processes off (.first() never emits,
        // .combine() yields nothing). Fall back to the nf-core empty-path sentinel
        // ([meta, []]) so the modules run without `--reference`. A value channel is
        // used so the same reference is broadcast to every BAM.
        ch_fasta_for_samtools = params.fasta
            ? ch_fasta.first()
            : Channel.value([[id: 'no_fasta'], []])

        if (params.dedup) {
            DEDUPLICATION(ch_aligned, ch_fasta_for_samtools, ch_for_cager)

            ch_for_cager = DEDUPLICATION.out.ch_for_cager
            ch_bam_bai = DEDUPLICATION.out.ch_bam_bai
        } else {
            SAMTOOLS_PROCESSING(ch_aligned, ch_fasta_for_samtools, ch_for_cager)

            ch_for_cager = SAMTOOLS_PROCESSING.out.ch_for_cager
            ch_bam_bai = SAMTOOLS_PROCESSING.out.ch_bam_bai
        }

        BAM_STATS_SAMTOOLS(ch_bam_bai, ch_fasta_for_samtools)

        // Feed samtools stats/flagstat/idxstats into the MultiQC report
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_SAMTOOLS.out.stats.collect{it[1]})
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_SAMTOOLS.out.flagstat.collect{it[1]})
        ch_multiqc_files = ch_multiqc_files.mix(BAM_STATS_SAMTOOLS.out.idxstats.collect{it[1]})

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
        // bowtie2 emits a single BAM path per sample (4 columns); STAR emits a
        // pair of bigWigs, now written as two comma-separated columns (path1,
        // path2) instead of a single bracketed "[str1 str2]" field.
        def header = params.bowtie2 ? "id,single_end,path,new_name" : "id,single_end,path1,path2,new_name"

        // Order of the samples in the merged sample list, and hence in the CAGEr
        // object and in every report plot that does not cluster samples: the order
        // of the user's sample sheet (or the natural order of the names derived from
        // the FASTQ files of --infolder), unless --sort_samples is set, in which case
        // the natural order (S1, S2, ..., S10). storeDir writes the merged sheet to
        // <outdir>/cager_sample_list/cager_sample_list.csv (in both maponly and
        // full-run mode) before the CAGEr part starts, mirroring the cageronly-mode
        // RELATIVISATION output, while the same channel is passed into CAGER below.
        def naturalKey = { String s -> s.replaceAll(/[0-9]+/) { String d -> d.padLeft(12, '0') } }
        if (params.input) {
            ordered_ids = Channel.value(
                file(params.input, checkIfExists: true)
                    .splitCsv(header: true, sep: ',')
                    .collect { row -> fixSampleName(row.sample)[0] }
                    .unique())
        } else {
            ordered_ids = PARAMETER_CHECKS.out.ch_fastq
                .map { meta, fastq -> meta.id }
                .toSortedList { a, b -> naturalKey(a) <=> naturalKey(b) }
        }
        merged_sample_file = ch_sample_files
            .map { table_line -> table_line.text.trim() }
            .toList()
            .map { lines -> [lines] }
            .combine(ordered_ids.map { ids -> [ids] })
            .map { lines, ids ->
                def sorted_lines = lines.toSorted { a, b ->
                    def id_a = a.split(',')[0]
                    def id_b = b.split(',')[0]
                    params.sort_samples ? naturalKey(id_a) <=> naturalKey(id_b) : ids.indexOf(id_a) <=> ids.indexOf(id_b)
                }
                ([header] + sorted_lines).join('\n')
            }
            .collectFile(
                name: "cager_sample_list.csv",
                storeDir: "${params.outdir}/cager_sample_list",
                newLine: true,
                sort: false)

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
    ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'cageseq_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )


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

    emit:
    report   = MULTIQC.out.report // channel: /path/to/multiqc_report.html
    versions = ch_versions        // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
