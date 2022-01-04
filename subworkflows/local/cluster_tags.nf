//
// cluster ctss and generate counts, count tables and QC
//
include { CTSS_PROCESS                         } from '../../modules/local/ctss_process' 
include { PARACLU                              } from '../../modules/local/paraclu'
include { TAG_CLUSTER_GENERATE_COUNTS          } from '../../modules/local/tag_cluster_generate_counts'
include { TAG_CLUSTER_GENERATE_COUNT_MATRIX    } from '../../modules/local/tag_cluster_generate_count_matrix'
include { TAG_CLUSTER_QC                       } from '../../modules/local/tag_cluster_qc'

workflow CLUSTER_TAGS {
    take:
    ch_ctss     // channel: [ val(meta), [ bam ] ]
    chrom_sizes // file: chromosome sizes
    gtf_bed     // file: GTF in bed format
    skip_qc     // boolean: skip QC

    main:

    ch_versions = Channel.empty()

    //process CTSS files for paraclu and run clustering
    ch_tag_clusters = Channel.empty()
    
    CTSS_PROCESS( ch_ctss.collect{it[1]} )
    ch_versions = ch_versions.mix(CTSS_PROCESS.out.versions)

    PARACLU( CTSS_PROCESS.out.ctss, params.min_cluster ).bed.set { ch_tag_clusters }
    ch_versions = ch_versions.mix(PARACLU.out.versions)
    
    // Generate per sample cluster bed-files and count table
    TAG_CLUSTER_GENERATE_COUNTS( ch_ctss, ch_tag_clusters )
    ch_versions = ch_versions.mix(TAG_CLUSTER_GENERATE_COUNTS.out.versions)
    
    TAG_CLUSTER_GENERATE_COUNT_MATRIX( TAG_CLUSTER_GENERATE_COUNTS.out.count_file.collect(), ch_tag_clusters )
    ch_versions = ch_versions.mix(TAG_CLUSTER_GENERATE_COUNT_MATRIX.out.versions)
    
    // CTSS QC
    ch_tag_cluster_qc = Channel.empty()
    if (!skip_qc){
        TAG_CLUSTER_QC( ch_ctss, gtf_bed, chrom_sizes)
        ch_versions = ch_versions.mix(TAG_CLUSTER_QC.out.versions.first())
        ch_tag_cluster_qc = TAG_CLUSTER_QC.out.rseqc
    }

    emit:
    tag_cluster     = ch_tag_clusters                                   // channel: [ ctss.clustered.simplified.bed ]
    tag_cluster_qc  = ch_tag_cluster_qc                                 // channel: [ val(meta), [ read_distribution.txt ] ]
    count_table     = TAG_CLUSTER_GENERATE_COUNTS.out.count_file        // channel: [ val(meta), [ bed ] ]
    count_matrix    = TAG_CLUSTER_GENERATE_COUNT_MATRIX.out.count_table // channel: [ count_table.tsv ]
    versions        = ch_versions                                       // channel: [ versions.yml ]

}