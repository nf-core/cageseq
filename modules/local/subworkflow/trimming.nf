/*
 * Trim adapters, 5'-Gs and remove artifacts if specified
 */

// Include them modules
params.cutadapt_trimming_options    = [:]
//params.cutadapt_5gtrim_options      = [:]
//params.cutadapt_artefact_options    = [:]

include { CUTADAPT_TRIMMING } from '../process/cutadapt_trimming'       addParams( options: params.cutadapt_trimming_options )
//include { CUTADAPT_5GTRIM } from '../process/cutadapt_5gtrim'           addParams( options: params.cutadapt_5gtrim_options )
//include { CUTADAPT_ARTEFACTS } from '../process/cutadapt_artefact'      addParams( options: params.cutadapt_artefact_options )

workflow TRIMMING_PREPROCESSING {
    take:
    reads           // channel: [ val(meta), [ reads ] ]

    main:
    
    // Trim adapters, eco-site and linker sequences
    CUTADAPT_TRIMMING( reads )

    cutadapt_version = CUTADAPT_TRIMMING.out.version
    
    // Trim Gs at 5'-site
    //CUTADAPT_5GTRIM( CUTADAPT_TRIMMING.out.reads )

    // Remove sequencing artefacts
    //CUTADAPT_ARTEFACTS( CUTADAPT_5GTRIM.out.reads )

    trim_reads = CUTADAPT_TRIMMING.out.reads

    emit:
    reads = trim_reads // channel: [ val(meta), [ reads ] ]
    cutadapt_version     //    path: *.version.txt
}