//
// Subworkflow for deduplication tasks
//

include { SAMTOOLS_SORT as SORT_FOR_FIXMATE} from '../../../modules/nf-core/samtools/sort/main.nf'
include { SAMTOOLS_FIXMATE } from '../../../modules/nf-core/samtools/fixmate/main.nf'
include { SAMTOOLS_SORT as SORT_AFTER_FIXMATE} from '../../../modules/nf-core/samtools/sort/main.nf'
include { SAMTOOLS_INDEX as INDEX_AFTER_FIXMATE} from '../../../modules/nf-core/samtools/index/main.nf'

include { SAMTOOLS_MARKDUP } from '../../../modules/nf-core/samtools/markdup/main.nf'
include { SAMTOOLS_INDEX as INDEX_DEDUP} from '../../../modules/nf-core/samtools/index/main.nf'

workflow DEDUPLICATION {
    take:
        ch_aligned
        ch_for_cager
        ch_fasta

    main:

        println("Deduplicating reads")
        SORT_FOR_FIXMATE (
            ch_aligned
        )
        SAMTOOLS_FIXMATE (
            SORT_FOR_FIXMATE.out.bam
        )
        ch_bam_to_sort = SAMTOOLS_FIXMATE.out.bam

        SORT_AFTER_FIXMATE(ch_bam_to_sort)
        INDEX_AFTER_FIXMATE(SORT_AFTER_FIXMATE.out.bam)

        // Prepare fasta channel for SAMTOOLS_MARKDUP
        ch_fasta_indexed = ch_fasta
            .map { fasta ->
                def meta = [:]
                def fai = file("${fasta}.fai")
                [meta, fasta, fai]
            }

        SAMTOOLS_MARKDUP (
            SORT_AFTER_FIXMATE.out.bam,
            ch_fasta_indexed
        )
        INDEX_DEDUP (SAMTOOLS_MARKDUP.out.bam)

        ch_bam_bai = SAMTOOLS_MARKDUP.out.bam.join(INDEX_DEDUP.out.bai)

        if (params.bowtie2) {
            ch_for_cager = SAMTOOLS_MARKDUP.out.bam
        }

    emit:
        ch_for_cager
        ch_bam_bai
}
