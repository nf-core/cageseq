#!/usr/bin/env Rscript

#
# QC 2: Tag cluster annotation, nucleotide and dinucleotide composition
#


# Load libraries
required.libraries <- c(
    "optparse",
    "rlang",
    "CAGEr",
    "GenomicFeatures",
    "ChIPseeker",
    "Biostrings",
    "tidyr",
    "viridis",
    "tidyverse",
    "ggplot2",
    "dplyr"
    )

for (lib in required.libraries) {
    suppressPackageStartupMessages(library(lib, character.only=TRUE, quietly = T))
}

# parse options
option_list = list(
    make_option(
        c("-i", "--cageexp_object"),
        type = "character",
        default = NULL,
        help = "Path to the CAGEexp object with tag clusters (Mandatory)"),
    make_option(
        c("-a", "--annotation"),
        type = "character",
        default = NULL,
        help = "Genome annotation package, eg TxDb.Hsapiens.UCSC.hg38.knownGene (Mandatory)"),
    make_option(
        c("-b", "--bsgenome"),
        type = "character",
        default = NULL,
        help = "Name of the BSgenome version to be used (Mandatory)"),
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
        c("-u", "--tssregion_up"),
        type = "integer",
        default = -3000,
        help = "Upstream distance to consider into TSS region for ChIPseeker annotation. Should be negative (Default = -3000)"),
    make_option(
        c("-d", "--tssregion_down"),
        type = "integer",
        default = 3000,
        help = "Downstream distance to consider into TSS region for ChIPseeker annotation. Should be positive (Default = 3000)"),
    make_option(
        c("-l", "--tsslogo_upstream"),
        type = "integer",
        default = 35,
        help = "Upstream nucleotides to consider fot the TSS logo plot (Default = 35)"),
    make_option(
        c("-p", "--project_dir"),
        type = "character",
        default = 0,
        help = "Project directory, from which the analysis is run."),
    make_option(
        c("-t", "--corrplot_tagCountThreshold"),
        type = "integer",
        default = 1,
        help = "Threshold for considering tags when calculating correlations of normalized CTSS (Default = 1)")
)

message("; Reading arguments from command line.")
opt_parser = optparse::OptionParser(option_list = option_list)
opt = optparse::parse_args(opt_parser)

# set variable names

ce_path         <- opt$cageexp_object
tx_annotation   <- opt$annotation
bsgenome        <- opt$bsgenome
iqlow           <- opt$iq_low
iqhigh          <- opt$iq_high
tssregion_up    <- opt$tssregion_up
tssregion_down  <- opt$tssregion_down
tsslogo_upstream    <- opt$tsslogo_upstream
project_dir     <- opt$project_dir
corrplot_tagCountThreshold <- opt$corrplot_tagCountThreshold

# installing BSgenome
source(file.path(project_dir, "bin/install_bsgenome.R"))
# import functions for second quality control and plotting
source(file.path(project_dir, "bin/plot_saving.R"))
source(file.path(project_dir, "bin/cager_nucleotide_composition_functions.R"))
source(file.path(project_dir, "bin/qc_plots.R"))

# Create folders for organized analysis
dir.create(file.path("plots"))
dir.create(file.path("tracks"))
dir.create(file.path("tables"))
dir.create(file.path("intermediate_cagerobj"))

reference_name <- install_bsgenome(bsgenome)

# Read in TxDb object
tx_annotation_obj <- loadDb(tx_annotation)

# Read in CAGEexp object
ce <- readRDS(ce_path)

# plot PCA
# extract normalized data
count_mat <- CTSSnormalizedTpmDF(ce)
for (i in 1:ncol(count_mat)){
    count_mat[,i] <- as.vector(count_mat[,i])
}
count_matmat <- as.matrix(count_mat)

plot_correlation(
    datatype="norm_CTSS",
    dataframe=CTSSnormalizedTpmDF(ce),
    corrplot_tagCountThreshold=corrplot_tagCountThreshold)
print("Normalized CTSS correlation plotted")

pca_plot <- plot_pcs(count_matmat)
save_plot(
    "CTSS_pca_plot.pdf",
    pca_plot
)
print("CTSS PCA plotted")


# extract tag clusters to GRanger object
sampleNames <- unname(CAGEr::sampleLabels(ce))
tag_clusters <- lapply(
    sampleNames,
    function (x) CAGEr::tagClustersGR(
        ce,
        sample = x,
        qLow = iqlow,
        qUp = iqhigh))
names(tag_clusters) <- sampleNames

# annotate peaks with chipseeker
peakAnno_list <- lapply(
    tag_clusters,
    function(x) ChIPseeker::annotatePeak(
        x,
        TxDb = tx_annotation_obj,
        tssRegion = c(tssregion_up, tssregion_down),
        sameStrand = TRUE,
        level = "transcript",
        genomicAnnotationPriority = c(
            "Promoter", "5UTR", "3UTR",
            "Exon", "Intron",
            "Downstream", "Intergenic"))
)

chipannot_plot <- ChIPseeker::plotAnnoBar(peakAnno_list)
save_plot(
    "chipseeker_tagCluster_annotation_plot.pdf",
    chipannot_plot
)

samplename <- names(peakAnno_list)[1]

# Plot sequence distribution at the dominant TSS for each sample
# "Promoter (<= 1kb)" is a proper annotation if tssRegion in annotatePeak is bigger than 1kb
# otherwise it would be just "Promoter"
# If there is only Promoter in the TxDb file, use that
if (abs(tssregion_up-tssregion_down) < 1000){
    promoter_annot <- "Promoter"
}else if ("Promoter (<=1kb)" %in% peakAnno_list[[samplename]]@annoStat$Feature) {
    promoter_annot <- "Promoter (<=1kb)"
}else{
    promoter_annot <- "Promoter"
}
for (sample in sampleNames){
    sample_annotation <- peakAnno_list[[sample]]@anno
    tsslogo_plot <- CAGEr::TSSlogo(
        sample_annotation |> subset(
            sample_annotation@elementMetadata$annotation == promoter_annot),
        upstream = tsslogo_upstream)
    save_plot(
        paste0(sample, "_tagcluster_dominantTSSlogos_plot.pdf"),
        tsslogo_plot
    )
}

# dinculeotide composition
weigthed_dinuc_vals_df <- extract_dinucleotide_information(ce, reference_name)
dinuclfreq_plot <- plot_dinucleotide_frequency(
    weigthed_dinuc_vals_df)
save_plot(
    "dinucleotide_frequencies_plot.pdf",
    dinuclfreq_plot
)

# Consensus clustered CTSS quality plots

consclustTpm <- CAGEr::consensusClustersTpm(ce)
# save matrix of sample per consensus cluster TPM
write.table(
    consclustTpm,
    file="tables/consensus_clusters_tpm.csv",
    quote = FALSE)
print("Consensus cluster tpms saved")

# count and plot the number of consensus clusters with signal
sample_cons_ctss_count <- list()
for (sample in CAGEr::sampleLabels(ce)) {
    sample_cons_ctss_count[[sample]] <- sum(
        as.vector(consclustTpm[,sample]) > 0)
}
sample_cons_ctss_count[["Union"]] <- dim(consclustTpm)[1]
consensus_ctss_plot <- plot_number_of_tag_clusters(
    sample_tag_count=sample_cons_ctss_count,
    yaxistitle="Number of non-zero consensus clusters",
    mytitle="Non-zero consensus clusters per sample and union")
save_plot(
    "consensus_counts_plot.pdf",
    consensus_ctss_plot)
print("Number of non-zero consensus clusters plotted")

# plot PCAs
pca_plot <- plot_pcs(consclustTpm)
save_plot(
    "consensus_clusters_pca_plot.pdf",
    pca_plot)
print("Consensus cluster PCA plotted")
