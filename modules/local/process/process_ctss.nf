// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CTSS_PROCESS {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta.id) }

    conda (params.enable_conda ? "bioconda::mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:5dde166a202fda0fda1facafc818a1ea0ff53ac7-0" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:5dde166a202fda0fda1facafc818a1ea0ff53ac7-0"
    } else {
        container "quay.io/biocontainers/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:5dde166a202fda0fda1facafc818a1ea0ff53ac7-0"
    }

    input:
    tuple val(meta), path(ctss)
    
    output:
    tuple val(meta), path("*")         , emit: ctss

    script:
    """
    cp ${bam} test.bam
    process_ctss.sh -t ${params.tpm_cluster_threshold} ${ctss}

    """
}
