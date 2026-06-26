//
// Subworkflow for deduplication tasks
//

include { SAMTOOLS_SORT as SORT_FOR_FIXMATE} from '../../../modules/nf-core/samtools/sort/main.nf'
include { SAMTOOLS_FIXMATE } from '../../../modules/nf-core/samtools/fixmate/main.nf'
include { SAMTOOLS_SORT as SORT_AFTER_FIXMATE} from '../../../modules/nf-core/samtools/sort/main.nf'
include { SAMTOOLS_INDEX as INDEX_AFTER_FIXMATE} from '../../../modules/nf-core/samtools/index/main.nf'

include { SAMTOOLS_DEDUP } from '../../../modules/local/samtools/dedup/main.nf'
include { SAMTOOLS_INDEX as INDEX_DEDUP} from '../../../modules/nf-core/samtools/index/main.nf'

workflow DEDUPLICATION {
    take:
        ch_aligned
        ch_fasta
        ch_for_cager

    main:

        // No on-the-fly indexing inside the sort steps: the name sort
        // (SORT_FOR_FIXMATE, '-n') cannot be index-written, and coordinate
        // indexing is handled by the dedicated INDEX_* processes below.
        ch_no_index = Channel.value([])

        // ch_fasta is a single-element queue channel; convert it to a value
        // channel with .first() so the same reference is broadcast to every
        // BAM. Without this, SAMTOOLS_SORT consumes the lone fasta on the
        // first sample and drops all the others.
        ch_fasta_value = ch_fasta.first()

        SORT_FOR_FIXMATE (
            ch_aligned,
            ch_fasta_value,
            ch_no_index
        )
        SAMTOOLS_FIXMATE (
            SORT_FOR_FIXMATE.out.bam
        )
        ch_bam_to_sort = SAMTOOLS_FIXMATE.out.bam

        SORT_AFTER_FIXMATE(ch_bam_to_sort, ch_fasta_value, ch_no_index)
        INDEX_AFTER_FIXMATE(SORT_AFTER_FIXMATE.out.bam)

        SAMTOOLS_DEDUP (SORT_AFTER_FIXMATE.out.bam)
        INDEX_DEDUP (SAMTOOLS_DEDUP.out.bam)

        ch_bam_bai = SAMTOOLS_DEDUP.out.bam.join(INDEX_DEDUP.out.bai)

        if (params.bowtie2) {
            ch_for_cager = SAMTOOLS_DEDUP.out.bam
        }

    emit:
        ch_for_cager
        ch_bam_bai
}
