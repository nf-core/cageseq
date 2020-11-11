/*
 * Perform alignment of processed reads using bowtie
 * and generate the generate the index first if necessary
 */

// Include them modules
params.index_options    = [:]
params.align_options    = [:]
params.samtools_options = [:]

include { UNTAR                 } from '../process/untar'                               addParams( options: params.index_options    )
include { BOWTIE_INDEX          } from '../process/bowtie_index'                        addParams( options: params.index_options    )
include { BOWTIE_ALIGN          } from '../process/bowtie_align'                        addParams( options: params.align_options    )
include { BOWTIE_SAMTOOLS       } from '../process/bowtie_samtools'                     addParams( options: params.samtools_options )

workflow ALIGN_BOWTIE {
    take:
    reads           // channel: [ val(meta), [ reads ] ]
    index           // file: path/to/bowtie.index
    fasta           // file: path/to/genome.fasta
    gtf             // file: path/to/genome.gtf

    main:
    // Create index if necessary
    if (index) {
        if (index.endsWith('.tar.gz')) {
            ch_index = UNTAR ( index ).untar
        } else {
            ch_index = file(index)
        }
    } else {
        ch_index = BOWTIE_INDEX ( fasta, gtf ).index
    }

    // Map reads with bowtie
    BOWTIE_ALIGN( reads, ch_index, gtf)

    // Convert SAM output to BAM and sort with samtools
    BOWTIE_SAMTOOLS( BOWTIE_ALIGN.out.sam )

    emit:
    orig_sam            = BOWTIE_ALIGN.out.sam
    log_out             = BOWTIE_ALIGN.out.log
    bam                 = BOWTIE_SAMTOOLS.out.bam
    bowtie_version      = BOWTIE_ALIGN.out.version
    samtools_version    = BOWTIE_SAMTOOLS.out.version

}