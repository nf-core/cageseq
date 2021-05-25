// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CTSS_CREATE {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta.id) }

    conda (params.enable_conda ? "bioconda::bedtools=2.30.0 bioconda::samtools=1.9" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:5dde166a202fda0fda1facafc818a1ea0ff53ac7-0"
    } else {
        container "quay.io/biocontainers/mulled-v2-8186960447c5cb2faa697666dc1e6d919ad23f3e:5dde166a202fda0fda1facafc818a1ea0ff53ac7-0"
    }

    input:
    tuple val(meta), path(bam)
    
    output:
    tuple val(meta), path("*.ctss.bed")         , emit: ctss

    script:
    def prefix     = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    make_ctss.sh -q 20 -i ${bam.baseName} -n ${meta.id}
    """
}
