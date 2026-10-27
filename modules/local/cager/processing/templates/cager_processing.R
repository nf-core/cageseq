#!/usr/bin/env Rscript

#
# Process data with CAGEr: normalization, clustering of tags, consensus cluster calling, and track export
#

suppressPackageStartupMessages({
    library(rlang)
    library(CAGEr)
    library(GenomicFeatures)
    library(dplyr)
    library(purrr)
    library(magrittr)
    library(stringr)
    library(tidyr)
    library(tibble)
    library(data.table)
    library(rtracklayer)
})

# Variables injected by Nextflow
ce_path             <- "${cager_obj}"
bsgenome_name       <- "${bsgenome_name}"
bsgenome_file       <- "${bsgenome_file}"
tx_annotation       <- "${txdb}"
range_min           <- as.integer(${params.norm_range_min})
range_max           <- as.integer(${params.norm_range_max})
method              <- "${params.norm_method}"
t_norm              <- as.integer(${params.t_norm})
alpha_str           <- "${params.alpha}"
alpha               <- if (alpha_str == "null") NULL else as.double(alpha_str)
sample_num_thr      <- as.integer(${params.sample_num_thr})
ctss_thr            <- as.integer(${params.ctss_thr})
distclu_maxDist     <- as.integer(${params.distclu_maxDist})
keepSingletonsAbove <- as.integer(${params.keepSingletonsAbove})
iqlow               <- as.double(${params.iq_low})
iqhigh              <- as.double(${params.iq_high})
iqw_tpm_threshold   <- as.integer(${params.iqw_tpm_threshold})
consensus_thr       <- as.integer(${params.consensus_thr})
consensus_dist      <- as.integer(${params.consensus_dist})
num_core            <- as.integer(${task.cpus})

bsgenome <- if (nchar(trimws(bsgenome_name)) > 0) bsgenome_name else bsgenome_file

# Import helper functions
source("${projectDir}/bin/install_bsgenome.R")
source("${projectDir}/bin/cager_normalization.R")
source("${projectDir}/bin/plot_saving.R")
source("${projectDir}/bin/qc_plots.R")
source("${projectDir}/bin/cager_clustering.R")
source("${projectDir}/bin/cager_consensus_clustering.R")
source("${projectDir}/bin/cager_track_export.R")

reference_name <- install_bsgenome(bsgenome)

# Create folders for organized analysis
dir.create("plots")
dir.create("tracks")
dir.create("tables")
dir.create("intermediate_cagerobj")

# Read in CAGEexp object
ce <- readRDS(ce_path)

# Normalization
ce <- cager_normalization(
    ce = ce,
    rangeMin = range_min,
    rangeMax = range_max,
    method = method,
    t_norm = t_norm,
    user_alpha = alpha)

# CTSS clustering
ce <- cager_clustering(
    ce = ce,
    iqw_plot_lim = c(0, 150),
    sample_num_thr = sample_num_thr,
    ctss_thr = ctss_thr,
    distclu_maxDist = distclu_maxDist,
    keepSingletonsAbove = keepSingletonsAbove,
    iqw_tpm_threshold = iqw_tpm_threshold,
    num_core = num_core,
    iqlow = iqlow,
    iqhigh = iqhigh)

# Consensus clustering of clustered CTSS
ce <- consensus_clustering(
    ce = ce,
    tpmThreshold = consensus_thr,
    maxDist = consensus_dist,
    tx_annotation = tx_annotation,
    num_core = 1,
    iqlow = iqlow,
    iqhigh = iqhigh)

# Save output RDS
saveRDS(ce, file = "intermediate_cagerobj/normalized_clustered_cagexp.rds")

# Track export (bigwig and bed)
export_tagclusters(ce, iqlow, iqhigh)
export_consensus_clusters(ce)

# Trim consensusClusters BED to 7 columns
bed_data <- read.table(
    "tracks/consensusClusters_prefix.bed",
    sep = "\t", header = FALSE, comment.char = "", quote = "")
write.table(
    bed_data[, 1:7],
    "tracks/consensusClusters.bed",
    sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
file.remove("tracks/consensusClusters_prefix.bed")

versions_yaml <- sprintf(
    '"%s":\n    R: %s\n    CAGEr: %s\n',
    "${task.process}",
    paste(R.Version()[c("major", "minor")], collapse = "."),
    as.character(packageVersion("CAGEr"))
)
writeLines(versions_yaml, "versions.yml")
