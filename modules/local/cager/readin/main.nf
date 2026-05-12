// Read in to CAGEr in bigwig or bam format

process CAGER_READIN {
    label 'process_medium'
    stageInMode 'copy'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/23/23193b56d3e81a11b9b23db31250aa040c7c158f8c346756d2c2a5569e9147dd/data'
        : 'community.wave.seqera.io/library/bioconductor-cager_bioconductor-genomicfeatures_r-biocmanager_r-dplyr_pruned:f9beb808f71e4139'} "

    input:
    path bsgenome_file
    val bsgenome_name
    val sample_table
    val data_type
    path ch_collected

    output:
    path "intermediate_cagerobj/initial_cagexp.rds", emit: rds
    path "versions.yml",                             emit: versions, topic: versions

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
