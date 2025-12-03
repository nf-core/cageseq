#!/usr/bin/env Rscript

#
# Process data with CAGEr: normalization, clustering of tags, consensus cluster calling, and track export
#

# Load libraries
required.libraries <- c(
    "optparse",
    "rlang",
    "CAGEr",
    "GenomicFeatures",
    "dplyr",
    "purrr",
    "magrittr",
    "stringr",
    "tidyr",
    "tibble",
    "data.table",
    "rtracklayer")

for (lib in required.libraries) {
    suppressPackageStartupMessages(library(lib, character.only=TRUE, quietly = T))
}

# parse options
option_list = list(
    make_option(
        c("-i", "--cageexp_object"),
        type = "character",
        default = NULL,
        help = "Path to the CAGEexp object with tags (Mandatory)"),
    make_option(
        c("-n", "--range_min"),
        type = "integer",
        default = 10,
        help = "CAGE tag range minimum for normalization calculation (Optional)"),
    make_option(
        c("-m", "--range_max"),
        type = "integer",
        default = 10000,
        help = "CAGE tag range maximum for normalization calculation (Optional)"),
    make_option(
        c("-e", "--method"),
        type = "character",
        default = "powerLaw",
        help = "Method for normalization (Optional)"),
    make_option(
        c("-t", "--t_norm"),
        type = "integer",
        default = 1*10^6,
        help = "Total number of tags. Setting it to 1 million (default) results in normalized tags per million (tpm) values (Optional)"),
    make_option(
        c("-a", "--alpha"),
        type = "double",
        help = "Alpha values from the reverse cumulative distribution fitting (Optional)"),
    make_option(
        c("-s", "--sample_num_thr"),
        type = "integer",
        default = 1,
        help = "Number of samples in which the CTSS Tpm threshold (ctss_thr) should be passed (Default = 1)"),
    make_option(
        c("-r", "--ctss_thr"),
        type = "integer",
        default = 1,
        help = "CTSS Tpm threshold which should be passed in sample_num_thr number of samples (Default = 1)"),
    make_option(
        c("-l", "--distclu_maxDist"),
        type = "integer",
        default = 20,
        help = "Maximum distance parameter for distclu CAGEr function (Default = 20)"),
    make_option(
        c("-k", "--keepSingletonsAbove"),
        type = "integer",
        default = 5,
        help = "Threshold above which to keep the singletons during tag clustering (Default = 5)"),
    make_option(
        c("-o", "--iq_low"),
        type = "double",
        default = 0.1,
        help = "Lower boundary of interquartile range (Default = 0.1)"),
    make_option(
        c("-g", "--iq_high"),
        type = "double",
        default = 0.9,
        help = "Higher boundary of interquartile range (Default = 0.9)"),
    make_option(
        c("-w", "--iqw_tpm_threshold"),
        type = "integer",
        default = 3,
        help = "Tpm threshold for plotting tagcluster IQwidth (Default = 3)"),
    make_option(
        c("-u", "--consensus_thr"),
        type = "integer",
        default = 5,
        help = "CTSS Tpm threshold for consensus clustering (Default = 5)"),
    make_option(
        c("-d", "--consensus_dist"),
        type = "integer",
        default = 100,
        help = "Distance threshold for consensus clustering (Default = 100)"),
    make_option(
        c("-x", "--annotation"),
        type = "character",
        default = NULL,
        help = "SQLite file with a TxDb genome annotation package (Mandatory)"),
    make_option(
        c("-p", "--project_dir"),
        type = "character",
        default = 0,
        help = "Project directory, from which the analysis is run."),
    make_option(
        c("-b", "--bsgenome"),
        type = "character",
        default = NULL,
        help = "Name of the BSgenome version to be used (Mandatory)"),
    make_option(
        c("-c", "--num_core"),
        type = "integer",
        default = 0,
        help = "Number of cores to use (Optional), defaults to 0 (no parallelization)")
)

message("; Reading arguments from command line.")
opt_parser = optparse::OptionParser(option_list = option_list)
opt = optparse::parse_args(opt_parser)

# set variable names

ce_path             <- opt$cageexp_object
range_min           <- opt$range_min
range_max           <- opt$range_max
method              <- opt$method
t_norm              <- opt$t_norm
alpha               <- opt$alpha
sample_num_thr      <- opt$sample_num_thr
ctss_thr            <- opt$ctss_thr
distclu_maxDist     <- opt$distclu_maxDist
keepSingletonsAbove <- opt$keepSingletonsAbove
iqlow               <- opt$iq_low
iqhigh              <- opt$iq_high
iqw_tpm_threshold   <- opt$iqw_tpm_threshold
consensus_thr       <- opt$consensus_thr
consensus_dist      <- opt$consensus_dist
tx_annotation       <- opt$annotation
project_dir         <- opt$project_dir
bsgenome            <- opt$bsgenome
num_core            <- opt$num_core

# import functions
# installing BSgenome
source(file.path(project_dir, "bin/install_bsgenome.R"))

# for analysis
# source(file.path(project_dir, "bin/cager_merge_replicates.R"))
source(file.path(project_dir, "bin/cager_normalization.R"))
source(file.path(project_dir, "bin/plot_saving.R"))
source(file.path(project_dir, "bin/qc_plots.R"))
source(file.path(project_dir, "bin/cager_clustering.R"))
source(file.path(project_dir, "bin/cager_consensus_clustering.R"))
source(file.path(project_dir, "bin/cager_track_export.R"))

reference_name <- install_bsgenome(bsgenome)

# Create folders for organized analysis
dir.create(file.path("plots"))
dir.create(file.path("tracks"))
dir.create(file.path("tables"))
dir.create(file.path("intermediate_cagerobj"))

# Read in CAGEexp object
ce <- readRDS(ce_path)

# Normalization
ce <- cager_normalization(
    ce=ce,
    rangeMin=range_min,
    rangeMax=range_max,
    method=method,
    t_norm=t_norm,
    user_alpha=alpha)

# CTSS clustering
# uses functions from qc_plots.R
ce <- cager_clustering(
    ce=ce,
    iqw_plot_lim=c(0, 150),
    sample_num_thr=sample_num_thr,
    ctss_thr=ctss_thr,
    distclu_maxDist=distclu_maxDist,
    keepSingletonsAbove=keepSingletonsAbove,
    iqw_tpm_threshold=iqw_tpm_threshold,
    num_core=num_core,
    iqlow=iqlow,
    iqhigh=iqhigh)

# Consensus clustering of clustered CTSS

ce <- consensus_clustering(
    ce=ce,
    tpmThreshold=consensus_thr,
    maxDist=consensus_dist,
    tx_annotation=tx_annotation,
    num_core=1,
    iqlow=iqlow,
    iqhigh=iqhigh)

# save output
# RDS
saveRDS(ce, file = "intermediate_cagerobj/normalized_clustered_cagexp.rds")

# Track export (bigwig and bed)
export_tagclusters(ce, iqlow, iqhigh)
export_consensus_clusters(ce)
