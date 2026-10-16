//
// Subworkflow to define flow from STAR
//

include { STAR_ALIGN } from '../../../modules/nf-core/star/align/main.nf'
include { STAR_GENOMEGENERATE } from '../../../modules/nf-core/star/genomegenerate/main.nf'
include { UCSC_WIGTOBIGWIG as UCSC_WIGTOBIGWIG_STR1 } from '../../../modules/nf-core/ucsc/wigtobigwig/main.nf'
include { UCSC_WIGTOBIGWIG as UCSC_WIGTOBIGWIG_STR2 } from '../../../modules/nf-core/ucsc/wigtobigwig/main.nf'

workflow STAR {

    take:
        ch_reads_to_align
        ch_fasta
        ch_index
        ch_gtf
        ch_chrom_sizes
        ch_multiqc_files

    main:

        ch_genome_name = channel.of(params.genome_name)

        sample_meta = ch_reads_to_align.map{ meta, _fastq ->
            meta = meta
            [meta]}

        if (!params.index) {
            STAR_GENOMEGENERATE (
                ch_fasta,
                ch_genome_name.combine(ch_gtf)
            )
            ch_index = sample_meta.combine(STAR_GENOMEGENERATE.out.index.map { _genome_name, index -> index })
        }

        STAR_ALIGN (
            ch_reads_to_align,
            ch_index,
            sample_meta.combine(ch_gtf),
            false
        )

        ch_aligned = STAR_ALIGN.out.bam_sorted_aligned

        ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log_final.collect{log -> log[1]})

        ch_chrom_sizes_for_wig = ch_chrom_sizes.map{ _meta, sizes -> sizes }.first()

        wigs = STAR_ALIGN.out.wig

        if (params.unique_only) {
            ch_wig_str1 = wigs.map { meta, wig -> [meta, wig[0]] }
            ch_wig_str2 = wigs.map { meta, wig -> [meta, wig[1]] }
        } else {
            ch_wig_str1 = wigs.map { meta, wig -> [meta, wig[2]] }
            ch_wig_str2 = wigs.map { meta, wig -> [meta, wig[3]] }
        }

        UCSC_WIGTOBIGWIG_STR1(ch_wig_str1, ch_chrom_sizes_for_wig)
        UCSC_WIGTOBIGWIG_STR2(ch_wig_str2, ch_chrom_sizes_for_wig)

        bigwig_ch_for_cager = UCSC_WIGTOBIGWIG_STR1.out.bw
            .mix(UCSC_WIGTOBIGWIG_STR2.out.bw)
            .groupTuple(size: 2)

    emit:
        bigwig_ch_for_cager = bigwig_ch_for_cager
        ch_aligned = ch_aligned
        ch_multiqc_files = ch_multiqc_files
}
