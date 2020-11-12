/*
 * Create CTSS from BAM files, make BigWig files, perform CTSS QC
 * Generate counts and count tables
 */

// Include them modules
params.ctss_options    = [:]

include { CTSS_CREATE          } from '../process/ctss_create'          addParams( options: params.ctss_options    )

workflow CTSS_GENERATION {
    take:
    bam                     // channel: [ val(meta), [ bam ] ]
    chrom_sizes             // file: chromosome sizes
    gtf_bed                 // file: GTF in bed format

    main:
    // Create CTSS
    CTSS_CREATE( bam )

    emit:
    ctss        =       CTSS_CREATE.out.ctss

}