//
// Subworkflow to get the BSgenome via forging or loading
//

include { GTF2TXDB      } from '../../../modules/local/gtf2txdb/main.nf'
include { FORGEBSGENOME } from '../../../modules/local/forgebsgenome/main.nf'

workflow PREPARE_CAGER_METADATA {

    take:
        ch_gtf

    main:

        // prepare or fetch BSgenome
        if (params.forgeseed) {
            forge_seed = file(params.forgeseed, checkIfExists: true)
            seqs_fasta = Channel.fromPath("${params.sourcedir}/*", checkIfExists: true).collect()
            FORGEBSGENOME (
                channel.value([[id: 'bsgenome'], forge_seed]),
                seqs_fasta
            )
        }

        if (params.bsgenome) {
            if (params.bsgenome.endsWith('.tar.gz')) {
                ch_bsgenome_file = file(
                    params.bsgenome,
                    checkIfExists: true)
                ch_bsgenome_name = ''
            } else {
                ch_bsgenome_file = file(
                    "$projectDir/assets/NO_FILE_BSGENOME")
                ch_bsgenome_name = params.bsgenome
            }
        } else {
            ch_bsgenome_file = FORGEBSGENOME.out.tarball.map { meta, tarball -> tarball }
            ch_bsgenome_name = ''
        }

        ch_txdb = GTF2TXDB(ch_gtf)
        ch_txdb_file = GTF2TXDB.out.txdb

    emit:
        ch_bsgenome_file
        ch_bsgenome_name
        ch_txdb_file
}
