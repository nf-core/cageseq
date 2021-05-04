// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CTSS_GENERATE_COUNTS {
    //tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta.id) }

    conda (params.enable_conda ? "bioconda::bedtools=2.26.0gx" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/quay.io/biocontainers/bedtools:2.26.0gx--he513fc3_4"
    } else {
        container "quay.io/biocontainers/bedtools:2.26.0gx--he513fc3_4"
    }

    input:
    tuple val(meta), path(ctss)
    path(clusters)
    
    output:
    path("*.txt")           , emit: count_files
    path("*.bed")           , emit: count_qc

    script:
    """
    intersectBed -a ${clusters} -b ${ctss} -loj -s > ${ctss}_counts_tmp

    echo ${meta.id} > ${ctss}_counts.txt

    bedtools groupby -i ${ctss}_counts_tmp -g 1,2,3,4,6 -c 11 -o sum > ${ctss}_counts.bed
    awk -v OFS='\t' '{if(\$6=="-1") \$6=0; print \$6 }' ${ctss}_counts.bed >> ${ctss}_counts.txt
    """
}
