/*
 * Create CTSS from BAM files, make BigWig files, perform CTSS QC
 * Generate counts and count tables
 */

// Include them modules
params.ctss_options         = [:]
params.bigwig_options       = [:]
params.paraclu_options      = [:]
params.count_matrix_options = [:]
params.ctss_qc_options      = [:]

include { CTSS_CREATE          } from '../process/ctss_create'              addParams( options: params.ctss_options  )
include { BIGWIG_CREATE }        from '../process/bigwig_create'            addParams( options: params.bigwig_options )
include { CTSS_PROCESS }         from '../process/process_ctss'             addParams( options: params.ctss_options )
include { PARACLU_CLUSTER }      from '../process/paraclu_cluster'          addParams( options: params.paraclu_options )
include { GENERATE_COUNT_MATRIX }from '../process/generate_count_matrix'    addParams( options: params.count_matrix_options )
include { CTSS_QC }              from '../process/ctss_qc'                  addParams( options: params.ctss_qc_options )

workflow CTSS_GENERATION {
    take:
    bam                     // channel: [ val(meta), [ bam ] ]
    chrom_sizes             // file: chromosome sizes
    gtf_bed                 // file: GTF in bed format

    main:
    // Create CTSS
    CTSS_CREATE( bam )

    // Create BigWig files
    if (params.bigwig){
        BIGWIG_CREATE( CTSS_CREATE.out.ctss, chrom_sizes )
    }

    //process CTSS files for paraclu and run clustering
    CTSS_PROCESS( CTSS_CREATE.out.ctss )
    PARACLU_CLUSTER( CTSS_PROCESS.out.ctss )

    // Generate the count matrix
    GENERATE_COUNT_MATRIX( CTSS_CREATE.out.ctss, PARACLU_CLUSTER.out.cluster )

    // CTSS QC
    if (!params.skip_ctss_qc){
        CTSS_QC( CTSS_CREATE.out.ctss, gtf_bed, chrom_sizes)
    }

    emit:
    ctss            =       CTSS_CREATE.out.ctss
    cluster         =       PARACLU_CLUSTER.out.cluster
    ctss_qc         =       CTSS_QC.out.rseqc
    //count_matrix    =       GENERATE_COUNT_MATRIX.out.count_table

}