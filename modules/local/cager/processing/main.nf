//
// Calling of tag clusters with CAGEr
//

process CAGER_PROCESSING {
    label 'process_verylong'
    stageInMode 'copy'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/23/23193b56d3e81a11b9b23db31250aa040c7c158f8c346756d2c2a5569e9147dd/data'
        : 'community.wave.seqera.io/library/bioconductor-cager_bioconductor-genomicfeatures_r-biocmanager_r-dplyr_pruned:f9beb808f71e4139'} "

    input:
    path cager_obj
    path bsgenome_file
    val bsgenome_name
    path txdb

    output:
    path "intermediate_cagerobj/normalized_clustered_cagexp.rds",          emit: rds
    tuple path("plots/*.pdf"), path("plots/*.txt"), path("plots/*plot.rds"), emit: results
    tuple path("tracks/*.bw"), path("tracks/*.bed"), path("tables/*.csv"),  emit: tracks
    path "versions.yml",                                                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'cager_processing.R'

    stub:
    """
    mkdir -p intermediate_cagerobj plots tracks tables
    touch intermediate_cagerobj/normalized_clustered_cagexp.rds
    touch plots/normalization_plot.pdf
    touch plots/normalization_plot.txt
    touch plots/normalization_plot.rds
    touch tracks/tagClusters.bw
    touch tracks/consensusClusters.bed
    touch tables/consensusClusters.csv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        CAGEr: \$(Rscript -e 'cat(as.character(packageVersion("CAGEr")))')
    END_VERSIONS
    """
}
