//
// Sanity checks on input parameters and creation of channels
//

include { samplesheetToList         } from 'plugin/nf-schema'
include { INPUT_FROM_FOLDER         } from '../input_from_folder/main.nf'

workflow PARAMETER_CHECKS {

    take:
        ch_fasta
        ch_index
        ch_versions

    main:

        if (params.input) {
            //
            // Create channel from samplesheet file provided through params.input
            //

            println("Reading in samplesheet")

            input_handler = Channel.fromPath(params.input, checkIfExists: true)

            println("Creating channel from samplesheet")

            ch_fastq = input_handler
                .splitCsv ( header:true, sep:',' )
                .map { create_fastq_channel(it) }
                .groupTuple(by: [0])
                .map{ meta, fastq -> [ meta, fastq.flatten() ] }

        } else if (params.infolder) {
            println("Reading in files from folder")
            ch_fastq = INPUT_FROM_FOLDER(
                params.infolder
            )
        } else {
            exit 1, 'Provide input by using the --input or the --infolder options.'
        }

        println("Initializing channels")
        sample_meta = ch_fastq.map{ meta, fastq ->
            meta = meta
            [meta]}

        ch_genome_name = Channel.of(params.genome_name)

        // if index is specified, it is used as input
        if (!params.genome && !params.index) {
            exit 1, 'Reference genome FASTA file (--fasta) or genome index (--index) should be specified.'
        } else if (params.index) {
            ch_pre_idx = Channel.fromPath(params.index, checkIfExists: true)
            ch_index = sample_meta.combine(ch_pre_idx)
            if (params.genome) {
                ch_pre_fa = Channel.fromPath(params.genome, checkIfExists: true)
                ch_fasta = ch_genome_name.combine(ch_pre_fa)
            } else {
                ch_fasta = Channel.empty()
            }
        } else {
            ch_pre_fa = Channel.fromPath(params.genome, checkIfExists: true)
            ch_fasta = ch_genome_name.combine(ch_pre_fa)
            ch_index = Channel.empty()
        }

        if (params.dist) {
            if (!params.dedup) {
                exit 1, 'The --dist option requires the --dedup option.'
            }
        }

        if (!params.bsgenome && (!params.forgeseed || !params.sourcedir)) {
            exit 1, 'Either the --bsgenome option or the following two options must be specified: --forgeseed, --sourcerdir.'
        } else if (params.bsgenome && (params.forgeseed || params.sourcedir)) {
            exit 1, 'The --bsgenome option and the following two options are mutually exclusive: --forgeseed, --sourcerdir.'
        }


    emit:
        ch_fasta
        ch_index
        ch_fastq
        ch_versions

}

// Format: [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample
    meta.single_end = row.single_end.toBoolean()

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []

    if ((file(row.fastq_1) == []) || (!file(row.fastq_1).exists())) {
        throw new Exception("Please check input samplesheet: Read 1 FastQ file does not exist!\nRead 1 FastQ file: ${row.fastq_1}")
    }

    if (meta.single_end) {
        fastq_meta = [ meta, [ file(row.fastq_1) ] ]
    } else {
        if ((file(row.fastq_2) == []) || (!file(row.fastq_2).exists())) {
            throw new Exception("Please check input samplesheet: Read 2 FastQ file does not exist!\nRead 2 FastQ file: ${row.fastq_2}")
        }

        fastq_meta = [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
    }

    return fastq_meta
}

//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[ params.genome ].containsKey(attribute)) {
            return params.genomes[ params.genome ][ attribute ]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" +
            "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
            "  Currently, the available genome keys are:\n" +
            "  ${params.genomes.keySet().join(", ")}\n" +
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}
