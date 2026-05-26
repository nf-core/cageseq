//
// Subworkflow to get the chromsizes
//

include { SAMTOOLS_FAIDX } from '../../../modules/nf-core/samtools/faidx/main.nf'

workflow PREPARE_MAPPING_METADATA {

    take:
        ch_fasta

    main:

        // prepare chromosome sizes
        if (params.genome || params.fasta) {

            chrom_size_fa = ch_fasta.map{ _meta, fasta ->
                def new_meta = [:]
                new_meta.id = "sizes"
                fasta = fasta
                [new_meta, fasta, []]
            }.unique()
            SAMTOOLS_FAIDX(
                chrom_size_fa,
                [true] )
            ch_chrom_sizes = SAMTOOLS_FAIDX.out.sizes

        } else { // a genome index was provided instead
            ch_chrom_sizes = channel.of([
                [id:"sizes"],
                [file( params.index + '/chrNameLength.txt' )]
            ])
        }

    emit:
        ch_chrom_sizes
        ch_fasta
}
