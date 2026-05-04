process CAGEFIGHTR_ENHANCERCALLING {
    label 'process_verylong'
    stageInMode 'copy'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-cagefightr:1.26.0--r44hdfd78af_0' :
        'biocontainers/bioconductor-cagefightr:1.26.0--r44hdfd78af_0' }"

    input:
    path cager_obj
    path txdb

    output:
    tuple path("intermediate_cagerobj/supported_enhancers.rds"), path("intermediate_cagerobj/nonTSS_enhancers.rds"), emit: rds
    tuple path("plots/*.pdf"), path("plots/*plot.rds"), emit: plots
    tuple path("tables/*.tsv"), path("tracks/*.bed"), emit: enhancer_table
    path "versions.yml", emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'cagefightr_enhancer_calling.R'

    stub:
    """
    mkdir -p intermediate_cagerobj plots tables tracks
    touch intermediate_cagerobj/supported_enhancers.rds
    touch intermediate_cagerobj/nonTSS_enhancers.rds
    touch plots/enhancers_plot.pdf
    touch plots/enhancers_plot.rds
    touch tables/enhancer_expression_per_sample.tsv
    touch tracks/enhancers.bed
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        CAGEfightR: \$(Rscript -e 'cat(as.character(packageVersion("CAGEfightR")))')
    END_VERSIONS
    """
}
