//
// Quality Control steps of CAGEr after clustering of CTSS
//

process CAGER_TAGCLUSTER_QC {
    label 'process_high'
    stageInMode 'copy'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/23/23193b56d3e81a11b9b23db31250aa040c7c158f8c346756d2c2a5569e9147dd/data'
        : 'community.wave.seqera.io/library/bioconductor-cager_bioconductor-genomicfeatures_r-biocmanager_r-dplyr_pruned:f9beb808f71e4139'} "


    input:
    path cager_obj
    path txdb
    path bsgenome_file
    val bsgenome_name

    output:
    path "tables/*.csv",                                    emit: counts_csv
    tuple path("plots/*plot.pdf"), path("plots/*plot.rds"), emit: plots
    path "plots/*correlations_matrix.rds",                 emit: correlation_rds
    path "versions.yml",                                   emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'cager_tagcluster_qc.R'

    stub:
    """
    mkdir -p tables plots
    touch tables/consensus_clusters_tpm.csv
    touch plots/consensus_clusters_pca_plot.pdf
    touch plots/consensus_clusters_pca_plot.rds
    touch plots/norm_CTSS_correlations_matrix.rds
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        CAGEr: \$(Rscript -e 'cat(as.character(packageVersion("CAGEr")))')
        ChIPseeker: \$(Rscript -e 'cat(as.character(packageVersion("ChIPseeker")))')
    END_VERSIONS
    """
}
