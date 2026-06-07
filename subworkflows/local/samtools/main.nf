//
// Processing of files after mapping
//

include { SAMTOOLS_SORT } from '../../../modules/nf-core/samtools/sort/main.nf'
include { SAMTOOLS_INDEX } from '../../../modules/nf-core/samtools/index/main.nf'

workflow SAMTOOLS_PROCESSING {
    take:
        ch_aligned
        ch_fasta
        ch_for_cager

    main:

        ch_index_format = Channel.value("bai")

        // ch_fasta is a single-element queue channel; convert it to a value
        // channel with .first() so the same reference is broadcast to every
        // BAM in ch_aligned. Without this, SAMTOOLS_SORT runs only once
        // (consuming the lone fasta) and all but the first sample are dropped.
        SAMTOOLS_SORT(ch_aligned, ch_fasta.first(), ch_index_format)
        SAMTOOLS_INDEX (SAMTOOLS_SORT.out.bam)
        ch_bam_bai = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.bai)
        if (params.bowtie2) {
            ch_for_cager = SAMTOOLS_SORT.out.bam
        }

    emit:
        ch_for_cager
        ch_bam_bai

}
