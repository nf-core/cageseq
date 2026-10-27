process GTF2TXDB {
    label 'process_medium'
    stageInMode 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-txdbmaker:1.2.0--r44hdfd78af_0' :
        'biocontainers/bioconductor-txdbmaker:1.2.0--r44hdfd78af_0' }"

    input:
    path gtf

    output:
    path "*.sqlite", emit: txdb
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'gtf_to_txdb.R'

    stub:
    """
    touch annotation_from_gtf.sqlite
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        txdbmaker: \$(Rscript -e 'cat(as.character(packageVersion("txdbmaker")))' 2>/dev/null || echo "1.2.0")
    END_VERSIONS
    """
}
