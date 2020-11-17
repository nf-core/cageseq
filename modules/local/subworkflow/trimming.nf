/*
 * Trim adapters, 5'-Gs and remove artifacts if specified
 */

// Include them modules
params.cutadapt_trimming_options    = [:]
params.cutadapt_5gtrim_options      = [:]
params.cutadapt_artefact_options    = [:]

include { CUTADAPT_TRIMMING } from '../process/cutadapt_trimming'       addParams( options: params.cutadapt_trimming_options )
include { CUTADAPT_5GTRIM } from '../process/cutadapt_5gtrim'           addParams( options: params.cutadapt_5gtrim_options )
include { CUTADAPT_ARTEFACT } from '../process/cutadapt_artefact'      addParams( options: params.cutadapt_artefact_options )

workflow TRIMMING_PREPROCESSING {
    take:
    reads           // channel: [ val(meta), [ reads ] ]
    artefacts_5p    // channel: path
    artefacts_3p    // channel: path

    main:
    trim_reads          =   reads
    cutadapt_log        =   Channel.empty()
    cutadapt_version    =   Channel.empty()
    

    if (!params.skip_trimming) {
        // Trim adapters, eco-site and linker sequences
        CUTADAPT_TRIMMING( trim_reads )
        cutadapt_version = CUTADAPT_TRIMMING.out.version
        trim_reads = CUTADAPT_TRIMMING.out.reads
        cutadapt_log = CUTADAPT_TRIMMING.out.log
        
        // Trim Gs at 5'-site
        if (params.trim_5g) {
            CUTADAPT_5GTRIM( trim_reads )
            trim_reads = CUTADAPT_5GTRIM.out.reads
        }

        // Remove sequencing artefacts
        if (params.trim_artifacts) {
            CUTADAPT_ARTEFACT( trim_reads, artefacts_5p, artefacts_3p )
            trim_reads = CUTADAPT_ARTEFACT.out.reads
        }
    }

    emit:
    reads = trim_reads // channel: [ val(meta), [ reads ] ]
    cutadapt_version     //    path: *.version.txt
    cutadapt_log
}