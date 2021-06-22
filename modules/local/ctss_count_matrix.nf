// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CTSS_COUNT_MATRIX {
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:'') }

    conda (params.enable_conda ? "bioconda::bioawk=1.0.6" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/bioawk:1.0--h5bf99c6_6"
    } else {
        container "quay.io/biocontainers/bioawk:1.0--h5bf99c6_6"
    }

    input:
    path(counts)
    path(clusters)
    
    output:
    path("*.tsv")           , emit: count_table

    script:
    """
    echo 'coordinates' > coordinates
    bioawk '{ print \$4}' ${clusters} >> coordinates
    paste -d "\t" coordinates ${counts} >> count_table.tsv
    """
}
