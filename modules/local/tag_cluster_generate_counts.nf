process TAG_CLUSTER_GENERATE_COUNTS {
    tag "$meta.id"
    label 'process_low'
    
    conda (params.enable_conda ? "bioconda::bedtools=2.27.0 conda-forge::gawk=5.1.0 bioconda::grep=2.14" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-22105f082fdf56207f1dcc5b6da71a14394e28d7:387d955c0a2cdb831ec519d636e4ffd7062d6ae1-0':
        'quay.io/biocontainers/mulled-v2-22105f082fdf56207f1dcc5b6da71a14394e28d7:387d955c0a2cdb831ec519d636e4ffd7062d6ae1-0' }"

    input:
    tuple val(meta), path(ctss) // channel: [ val(meta), [ ctss ] ]
    path(clusters)              // path: to bed file with clusters
    
    output:
    path("*.txt")           , emit: count_file
    path("*.bed")           , emit: count_bed
    path  "versions.yml"    , emit: versions
    
    script:
    """
    intersectBed -a ${clusters} -b ${ctss} -loj -s > ${ctss}_counts_tmp

    echo ${meta.id} > ${ctss}_counts.txt

    bedtools groupby -i ${ctss}_counts_tmp -g 1,2,3,4,6 -c 11 -o sum > ${ctss}_counts.bed
    awk -v OFS='\t' '{if(\$6=="-1") \$6=0; print \$6 }' ${ctss}_counts.bed >> ${ctss}_counts.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
        gawk: \$(echo \$(awk --version 2>&1) | sed 's/^.*GNU Awk //; s/, .*\$//')
    END_VERSIONS
    """
}
