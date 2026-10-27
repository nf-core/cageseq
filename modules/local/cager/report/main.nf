// Creating markdown report from results

process CAGER_REPORT {
    label 'process_medium'
    stageInMode 'copy'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/23/23193b56d3e81a11b9b23db31250aa040c7c158f8c346756d2c2a5569e9147dd/data'
        : 'community.wave.seqera.io/library/bioconductor-cager_bioconductor-genomicfeatures_r-biocmanager_r-dplyr_pruned:f9beb808f71e4139'} "


    input:
    path rmarkd_template
    tuple path(tss_hm_ta_plots), path(tss_hm_ta_data)
    path tag_corr_m
    tuple path(cc_iqw_rc_plots), path(cc_txt), path(cc_iqw_rc_data)
    tuple path(tca_dn_n_plots), path(tca_dn_n_data)
    path tagcluster_corr_m
    tuple path(enhancer_plots), path(enhancer_data)
    path cageexp_object

    output:
    path "*.html"

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'cager_report.R'

    stub:
    """
    touch cager_report.html
    """
}
