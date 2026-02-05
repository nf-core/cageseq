//
// Steps for creating summary statistics for quality check
//

include { SAMTOOLS_STATS } from '../../../modules/nf-core/samtools/stats/main.nf'
include { SAMTOOLS_IDXSTATS } from '../../../modules/nf-core/samtools/idxstats/main.nf'
include { SAMTOOLS_FLAGSTAT } from '../../../modules/nf-core/samtools/flagstat/main.nf'


//  TODO: replace with https://github.com/nf-core/modules/blob/master/subworkflows/nf-core/bam_stats_samtools/main.nf
workflow SAMTOOLS_STATISTICS {
    take:
        ch_bam_bai
        ch_fasta
        ch_multiqc_files
        ch_versions

    main:
        if (params.genome) {
            ch_meta_fasta = ch_bam_bai
                .combine(ch_fasta)
                .map{[it[3], it[4]]}
        } else {
            ch_meta_fasta = ch_bam_bai
                .combine(channel.value("NO_FASTA"))
                .combine(channel.fromPath(
                    file("$projectDir/assets/NO_FILE_FASTA",
                    checkIfExists: true)))
                .map{[it[3], it[4]]}
        }

        SAMTOOLS_STATS (
            ch_bam_bai,
            ch_meta_fasta
        )

        ch_versions = ch_versions.mix(SAMTOOLS_STATS.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_STATS.out.stats.collect{it[1]})

        SAMTOOLS_FLAGSTAT ( ch_bam_bai )
        ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_FLAGSTAT.out.flagstat.collect{it[1]})

        SAMTOOLS_IDXSTATS ( ch_bam_bai )
        ch_multiqc_files = ch_multiqc_files.mix(SAMTOOLS_IDXSTATS.out.idxstats.collect{it[1]})

    emit:
        ch_multiqc_files
        ch_versions
}
