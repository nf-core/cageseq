//
// Create CTSS from BAM files, make BigWig files
//

include { BEDTOOLS_BAMTOBED                   } from '../../modules/nf-core/modules/bedtools/bamtobed/main'
include { CTSS_CREATE                         } from '../../modules/local/ctss_create'
include { BEDTOBEDGRAPH_BYSTRAND              } from '../../modules/local/bedtobedgraph_bystrand'
include { UCSC_BEDGRAPHTOBIGWIG as BGTOBW_POS } from '../../modules/nf-core/modules/ucsc/bedgraphtobigwig/main'
include { UCSC_BEDGRAPHTOBIGWIG as BGTOBW_NEG } from '../../modules/nf-core/modules/ucsc/bedgraphtobigwig/main'


workflow GENERATE_CTSS {
    take:
    bam          // channel: [ val(meta), [ bam ] ]
    genome_sizes // path: path/to/genome_sizes.txt

    main:

    ch_versions = Channel.empty()

    // Create CTSS
    BEDTOOLS_BAMTOBED( bam )
    ch_versions = ch_versions.mix(BEDTOOLS_BAMTOBED.out.versions.first())

    CTSS_CREATE( BEDTOOLS_BAMTOBED.out.bed ).ctss.set{ch_ctss}
    ch_versions = ch_versions.mix(CTSS_CREATE.out.versions.first())

    // Create BigWig files
    ch_bigwig = Channel.empty()
    if (params.bigwig){
        BEDTOBEDGRAPH_BYSTRAND(ch_ctss)
        ch_versions = ch_versions.mix(BEDTOBEDGRAPH_BYSTRAND.out.versions)

        BGTOBW_POS(BEDTOBEDGRAPH_BYSTRAND.out.pos_bedgraph, genome_sizes)
        ch_bigwig = BGTOBW_POS.out.bigwig
        BGTOBW_NEG(BEDTOBEDGRAPH_BYSTRAND.out.neg_bedgraph, genome_sizes)
        ch_bigwig = ch_bigwig.mix(BGTOBW_NEG.out.bigwig)
        ch_versions = ch_versions.mix(BGTOBW_NEG.out.versions)
    }

    emit:
    ctss     = ch_ctss     // channel: [ val(meta), [ ctss ] ]
    bigwig   = ch_bigwig   // channel: [ val(meta), [ bigwig ] ]
    versions = ch_versions // channel: [ versions.yml ]
}
