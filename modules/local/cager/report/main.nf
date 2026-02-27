// Creating markdown report from results

process CAGER_REPORT {
    label 'process_medium'
    stageInMode 'copy'

    conda "bioconda::bioconductor-cager=2.12.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-cager:2.12.0--r44hdfd78af_0' :
        'biocontainers/bioconductor-cager:2.12.0--r44hdfd78af_0' }"

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
