// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process GENERATE_COUNT_MATRIX {
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
    path(clusters)
    
    output:
    path("*.txt")           , emit: count_files
    path("*.bed")           , emit: count_qc
    path("*.tsv")           , emit: count_table

    script:
    clusters.collect()
    """
    intersectBed -a ${clusters} -b ${ctss} -loj -s > ${ctss}_counts_tmp

    echo ${name} > ${ctss}_counts.txt

    bedtools groupby -i ${ctss}_counts_tmp -g 1,2,3,4,6 -c 11 -o sum > ${ctss}_counts.bed
    awk -v OFS='\t' '{if($6=="-1") $6=0; print $6 }' ${ctss}_counts.bed >> ${ctss}_counts.txt

    echo 'coordinates' > coordinates
    awk '{ print $4}' ${clusters} >> coordinates
    paste -d "\t" coordinates ${counts} >> count_table.tsv

    """
}
