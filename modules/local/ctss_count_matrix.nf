// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CTSS_COUNT_MATRIX {
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:'') }


    conda     (params.enable_conda ? "conda-forge::sed=4.7" : null)
    container "biocontainers/biocontainers:v1.2.0_cv1"

    input:
    path(counts)
    path(clusters)
    
    output:
    path("*.tsv")           , emit: count_table

    script:
    """
    echo 'coordinates' > coordinates
    awk '{ print \$4}' ${clusters} >> coordinates
    paste -d "\t" coordinates ${counts} >> count_table.tsv
    """
}
