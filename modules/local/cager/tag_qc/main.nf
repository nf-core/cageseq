//
// Quality Control steps of CAGEr
//

process CAGER_TAG_QC {
    label 'process_verylong'
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
    path "intermediate_cagerobj/annotated_cagexp.rds",      emit: cager_rds
    path "plots/*correlations_matrix.rds",                  emit: correlation_rds
    tuple path("plots/*plot.pdf"), path("plots/*plot.rds"), emit: plots
    path "versions.yml",                                    emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'cager_tag_qc.R'

    stub:
    """
    mkdir -p intermediate_cagerobj plots
    touch intermediate_cagerobj/annotated_cagexp.rds
    touch plots/tag_region_annotation_plot.pdf
    touch plots/tag_region_annotation_plot.rds
    touch plots/CTSS_correlations_matrix.rds
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        CAGEr: \$(Rscript -e 'cat(as.character(packageVersion("CAGEr")))')
    END_VERSIONS
    """
}
