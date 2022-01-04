process CTSS_PROCESS {
    tag "pooled_ctss"
    label 'process_low'
    
    conda (params.enable_conda ? "bioconda::bedtools=2.27.0 conda-forge::gawk=5.1.0 bioconda::grep=2.14" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-22105f082fdf56207f1dcc5b6da71a14394e28d7:387d955c0a2cdb831ec519d636e4ffd7062d6ae1-0':
        'quay.io/biocontainers/mulled-v2-22105f082fdf56207f1dcc5b6da71a14394e28d7:387d955c0a2cdb831ec519d636e4ffd7062d6ae1-0' }"

    input:
    path(ctss) // list: all ctss files

    output:
    path("*.ctss.bed") , emit: ctss
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "pooled_ctss"
    
    """
    process_ctss.sh ${args} ${ctss}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
        gawk: \$(echo \$(gawk --version 2>&1) | sed 's/^.*GNU Awk //; s/, .*\$//')
    END_VERSIONS
    """
}
