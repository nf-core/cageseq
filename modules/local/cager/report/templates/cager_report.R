#!/usr/bin/env Rscript

library(rmarkdown)

# Variables injected by Nextflow
corrplot_tagCountThreshold <- "${params.corrplot_tagCountThreshold}"
norm_range_min             <- "${params.norm_range_min}"
norm_range_max             <- "${params.norm_range_max}"
norm_method                <- "${params.norm_method}"
t_norm                     <- "${params.t_norm}"
alpha                      <- "${params.alpha}"
sample_num_thr             <- "${params.sample_num_thr}"
ctss_thr                   <- "${params.ctss_thr}"
distclu_maxDist            <- "${params.distclu_maxDist}"
keepSingletonsAbove        <- "${params.keepSingletonsAbove}"
iq_low                     <- "${params.iq_low}"
iq_high                    <- "${params.iq_high}"
iqw_tpm_threshold          <- "${params.iqw_tpm_threshold}"
tssregion_up               <- "${params.tssregion_up}"
tssregion_down             <- "${params.tssregion_down}"
tsslogo_upstream           <- "${params.tsslogo_upstream}"
consensus_dist             <- "${params.consensus_dist}"
consensus_thr              <- "${params.consensus_thr}"
cfBalanceThreshold         <- "${params.cfBalanceThreshold}"
unexpressed                <- "${params.unexpressed}"
minSamples                 <- "${params.minSamples}"
ce                         <- readRDS("${cageexp_object}")

rmarkdown::render("${rmarkd_template}")
