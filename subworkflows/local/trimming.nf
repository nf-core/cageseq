/*
 * Trim adapters, 5'-Gs and remove artifacts if specified
 */

include { CUTADAPT as CUTADAPT_TRIMADAPTERS  } from '../../modules/nf-core/modules/cutadapt/main'
include { CUTADAPT as CUTADAPT_TRIM5G        } from '../../modules/nf-core/modules/cutadapt/main'
include { CUTADAPT as CUTADAPT_TRIMARTIFACTS } from '../../modules/nf-core/modules/cutadapt/main'

workflow TRIMMING_PREPROCESSING {
    take:
    reads      // channel: [ val(meta), [ reads ] ]
    artifacts_5p    // string: path
    artifacts_3p    // string: path
    trim_adapters   // boolean: true/false
    trim_5g         // boolean: true/false
    trim_artifacts  // boolean: true/false
    skip_trimming   // boolean: true/false 

    main:
    
    cutadapt_log = Channel.empty()
    ch_versions  = Channel.empty()
    
    
    trim_reads = reads
    if (!skip_trimming) {
    //     Trim adapters, eco-site and linker sequences
        if (trim_adapters) {
            CUTADAPT_TRIMADAPTERS( trim_reads )
            trim_reads = CUTADAPT_TRIMADAPTERS.out.reads
            ch_versions = ch_versions.mix(CUTADAPT_TRIMADAPTERS.out.versions)
            cutadapt_log = cutadapt_log.mix(CUTADAPT_TRIMADAPTERS.out.log)
        }
        // Trim Gs at 5'-site
        if (trim_5g) {

            CUTADAPT_TRIM5G( trim_reads )
            trim_reads = CUTADAPT_TRIM5G.out.reads
            ch_versions = ch_versions.mix(CUTADAPT_TRIM5G.out.versions)
            cutadapt_log = cutadapt_log.mix(CUTADAPT_TRIM5G.out.log)
        }

        // Remove sequencing artifacts
        if (trim_artifacts) {
            // Channels for artifacts 5'-end and 3'-end
            ch_5end_artifacts = Channel.fromPath(params.artifacts_5end)
            ch_3end_artifacts = Channel.fromPath(params.artifacts_3end)
            
            CUTADAPT_TRIMARTIFACTS( trim_reads )
            trim_reads = CUTADAPT_TRIMARTIFACTS.out.reads
            ch_versions = ch_versions.mix(CUTADAPT_TRIMARTIFACTS.out.versions)
            cutadapt_log = cutadapt_log.mix(CUTADAPT_TRIMARTIFACTS.out.log)
        }
    }

    emit:
    reads = trim_reads   // channel: [ val(meta), [ reads ] ]
    cutadapt_log
    versions = ch_versions     // channel: [ versions.yml ]
    
}