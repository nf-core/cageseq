// Creating markdown report from results

process CAGER_REPORT {
    label 'process_medium'
    stageInMode 'copy'

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

    """
    #!/usr/bin/env Rscript
    library(rmarkdown)

    corrplot_tagCountThreshold <- '${params.corrplot_tagCountThreshold}'
    norm_range_min <- '${params.norm_range_min}'
    norm_range_max <- '${params.norm_range_max}'
    norm_method <- '${params.norm_method}'
    t_norm <- '${params.t_norm}'
    alpha <- '${params.alpha}'
    sample_num_thr <- '${params.sample_num_thr}'
    ctss_thr <- '${params.ctss_thr}'
    distclu_maxDist <- '${params.distclu_maxDist}'
    keepSingletonsAbove <- '${params.keepSingletonsAbove}'
    iq_low <- '${params.iq_low}'
    iq_high <- '${params.iq_high}'
    cons_full_span <- '${params.cons_full_span}'
    iqw_tpm_threshold <- '${params.iqw_tpm_threshold}'
    tssregion_up <- '${params.tssregion_up}'
    tssregion_down <- '${params.tssregion_down}'
    tsslogo_upstream <- '${params.tsslogo_upstream}'
    consensus_dist <- '${params.consensus_dist}'
    consensus_thr <- '${params.consensus_thr}'
    cfBalanceThreshold <- '${params.cfBalanceThreshold}'
    unexpressed <- '${params.unexpressed}'
    minSamples <- '${params.minSamples}'
    ce <- readRDS('${cageexp_object}')

    rmarkdown::render('${rmarkd_template}')
    """
}
