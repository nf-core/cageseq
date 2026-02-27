//
// Calling of tag clusters with CAGEr
//

process CAGER_PROCESSING {
    label 'process_verylong'
    stageInMode 'copy'

    conda "bioconda::bioconductor-cager=2.12.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7a/7a2d31d5909213aff91b251bea788ca05f91609dfe33803d985f0dc9b4aeec64/data' :
        'bioconductor-cager_bioconductor-genomicfeatures_r-dplyr_r-purrr_pruned:d3d7e0a64babeca7' }"

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
