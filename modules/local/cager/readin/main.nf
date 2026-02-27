// Read in to CAGEr in bigwig or bam format

process CAGER_READIN {
    label 'process_medium'
    stageInMode 'copy'

    conda "bioconda::bioconductor-cager=2.12.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-cager:2.12.0--r44hdfd78af_0' :
        'biocontainers/bioconductor-cager:2.12.0--r44hdfd78af_0' }"

    input:
    path bsgenome_file
    val bsgenome_name
    val sample_table
    val data_type
    path ch_collected

    output:
    path "intermediate_cagerobj/initial_cagexp.rds", emit: rds
    path "versions.yml",                             emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'cager_readin.R'

    stub:
    """
    mkdir -p intermediate_cagerobj
    touch intermediate_cagerobj/initial_cagexp.rds
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        CAGEr: \$(Rscript -e 'cat(as.character(packageVersion("CAGEr")))')
    END_VERSIONS
    """
}
