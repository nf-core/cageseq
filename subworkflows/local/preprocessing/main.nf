//
// Processing before mapping
//

include { CAT_FASTQ } from '../../../modules/nf-core/cat/fastq/main.nf'
include { FASTQC } from '../../../modules/nf-core/fastqc/main.nf'
include { READ_REMOVAL } from '../../../modules/local/read_removal/main.nf'
include { TRIMGALORE } from '../../../modules/nf-core/trimgalore/main.nf'
include { CUTADAPT } from '../../../modules/nf-core/cutadapt/main.nf'

workflow PREPROCESSING {

    take:
        ch_fastq
        ch_multiqc_files

    main:
        CAT_FASTQ (
            ch_fastq
        ).reads.set { ch_cat_fastq }

        FASTQC (
            ch_cat_fastq
        )

        if (params.remove_non_g){
            ch_cat_fastq = READ_REMOVAL (ch_cat_fastq)
        }

        TRIMGALORE (
            ch_cat_fastq
        )

        if (!params.nogtrim) {
            CUTADAPT (
                TRIMGALORE.out.reads
            )
        }

        ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.log.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.zip.collect{it[1]}.ifEmpty([]))
        ch_reads_to_align = !params.nogtrim ? CUTADAPT.out.reads : TRIMGALORE.out.reads

    emit:
        ch_reads_to_align
        ch_multiqc_files

}
