//
// Subworkflow to define flow from Bowtie2
//

include { BOWTIE2_BUILD } from '../../../modules/nf-core/bowtie2/build/main.nf'
include { BOWTIE2_ALIGN } from '../../../modules/nf-core/bowtie2/align/main.nf'
include { SAMTOOLS_VIEW_MAPQ } from '../../../modules/local/samtools/view_mapq/main.nf'

workflow BOWTIE2 {

    take:
        ch_reads_to_align
        ch_fasta
        ch_index
        ch_multiqc_files

    main:
        sample_meta = ch_reads_to_align.map{ meta, fastq ->
            meta = meta
            [meta]}

        if (!params.index) {
            BOWTIE2_BUILD (
                ch_fasta
            )
            ch_index = sample_meta.combine(BOWTIE2_BUILD.out.index.map { genome_name, index -> index } )
        } else {
            ch_index = sample_meta.combine(ch_index.map { genome_name, index -> index })
        }

        if (params.genome) {
            ch_fasta = sample_meta.combine(ch_fasta.map { genome_name, fasta -> fasta } )
        } else {
            ch_fasta = sample_meta.combine(channel.fromPath("$projectDir/assets/NO_FILE_FASTA", checkIfExists: true))
        }

        BOWTIE2_ALIGN (
            ch_reads_to_align,
            ch_index,
            ch_fasta,
            false,
            false
        )
        ch_multiqc_files = ch_multiqc_files.mix(BOWTIE2_ALIGN.out.log.collect{it[1]})

        SAMTOOLS_VIEW_MAPQ ( BOWTIE2_ALIGN.out.bam )

        ch_aligned = SAMTOOLS_VIEW_MAPQ.out.bam

    emit:
        ch_aligned
        ch_multiqc_files

}
