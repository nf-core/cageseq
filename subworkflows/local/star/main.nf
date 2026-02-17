//
// Subworkflow to define flow from STAR
//

include { STAR_ALIGN } from '../../../modules/nf-core/star/align/main.nf'
include { STAR_GENOMEGENERATE } from '../../../modules/nf-core/star/genomegenerate/main.nf'
include { UCSC_WIGTOBIGWIG } from '../../../modules/nf-core/ucsc/wigtobigwig/main.nf'

workflow STAR {

    take:
        ch_reads_to_align
        ch_fasta
        ch_index
        ch_gtf
        ch_chrom_sizes
        ch_multiqc_files

    main:

        ch_genome_name = Channel.of(params.genome_name)

        sample_meta = ch_reads_to_align.map{ meta, fastq ->
            meta = meta
            [meta]}

        if (!params.index) {
            STAR_GENOMEGENERATE (
                ch_fasta,
                ch_genome_name.combine(ch_gtf)
            )
            ch_index = sample_meta.combine(STAR_GENOMEGENERATE.out.index.map { it[1] })
        }

        STAR_ALIGN (
            ch_reads_to_align,
            ch_index,
            sample_meta.combine(ch_gtf),
            false,
            params.seq_platform,
            params.seq_center
        )

        ch_aligned = STAR_ALIGN.out.bam_sorted_aligned

        ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log_final.collect{it[1]})

        ch_chrom_sizes_for_wig = ch_chrom_sizes.map{meta, sizes ->
            sizes = sizes
            sizes}

        wigs = STAR_ALIGN.out.wig

        if (params.unique_only){
            wigs_for_conversion = wigs.map{ meta, wigs ->
                meta = meta
                wigs_to_use = [wigs[0], wigs[1]]
                [meta, wigs_to_use]
            }
        } else {
            wigs_for_conversion = wigs.map{ meta, wigs ->
                meta = meta
                wigs_to_use = [wigs[2], wigs[3]]
                [meta, wigs_to_use]
            }
        }

        UCSC_WIGTOBIGWIG (
            wigs_for_conversion,
            ch_chrom_sizes_for_wig
        )

        bigwig_ch_for_cager = UCSC_WIGTOBIGWIG.out.bw

    emit:
        bigwig_ch_for_cager
        ch_aligned
        ch_multiqc_files
}
