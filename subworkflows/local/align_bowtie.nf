/*
 * Perform alignment of processed reads using bowtie
 * and generate the generate the index first if necessary
 */

// Include them modules
params.index_options    = [:]
params.align_options    = [:]
params.samtools_options = [:]

include { UNTAR                 }   from '../../modules/local/untar'                                addParams( options: params.index_options    )
include { BOWTIE_INDEX          }   from '../../modules/local/bowtie_index'                         addParams( options: params.index_options    )
include { BOWTIE_ALIGN          }   from '../../modules/local/bowtie_align'                         addParams( options: params.align_options    )
include { SAMTOOLS_SAMTOBAM     }   from '../../modules/local/samtools_samtobam'                    addParams( options: params.samtools_options )
include { BAM_SORT_SAMTOOLS   }     from './bam_sort_samtools'                                      addParams( options: params.samtools_options )

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

    // Convert SAM output to BAM 
    SAMTOOLS_SAMTOBAM( BOWTIE_ALIGN.out.sam )
    // Sort, index BAM file and run samtools stats, flagstat and idxstats
    BAM_SORT_SAMTOOLS ( SAMTOOLS_SAMTOBAM.out.bam )

    emit:
    orig_sam            = BOWTIE_ALIGN.out.sam
    log_out             = BOWTIE_ALIGN.out.log
    bowtie_version      = BOWTIE_ALIGN.out.version

    bam              = BAM_SORT_SAMTOOLS.out.bam      // channel: [ val(meta), [ bam ] ]
    bai              = BAM_SORT_SAMTOOLS.out.bai      // channel: [ val(meta), [ bai ] ]
    stats            = BAM_SORT_SAMTOOLS.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat         = BAM_SORT_SAMTOOLS.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats         = BAM_SORT_SAMTOOLS.out.idxstats // channel: [ val(meta), [ idxstats ] ]
    samtools_version = BAM_SORT_SAMTOOLS.out.version  //    path: *.version.txt

}