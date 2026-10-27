#!/usr/bin/env Rscript

#
# QC 2: Tag cluster annotation, nucleotide and dinucleotide composition
#

suppressPackageStartupMessages({
    library(rlang)
    library(CAGEr)
    library(GenomicFeatures)
    library(ChIPseeker)
    library(Biostrings)
    library(tidyr)
    library(viridis)
    library(tidyverse)
    library(ggplot2)
    library(dplyr)
})

# Variables injected by Nextflow
ce_path                    <- "${cager_obj}"
tx_annotation              <- "${txdb}"
bsgenome_name              <- "${bsgenome_name}"
bsgenome_file              <- "${bsgenome_file}"
iqlow                      <- as.double(${params.iq_low})
iqhigh                     <- as.double(${params.iq_high})
tssregion_up               <- as.integer(${params.tssregion_up})
tssregion_down             <- as.integer(${params.tssregion_down})
tsslogo_upstream           <- as.integer(${params.tsslogo_upstream})
corrplot_tagCountThreshold <- as.integer(${params.corrplot_tagCountThreshold})

bsgenome <- if (nchar(trimws(bsgenome_name)) > 0) bsgenome_name else bsgenome_file

# Import helper functions
source("${projectDir}/bin/install_bsgenome.R")
source("${projectDir}/bin/plot_saving.R")
source("${projectDir}/bin/cager_nucleotide_composition_functions.R")
source("${projectDir}/bin/qc_plots.R")

# Create folders for organized analysis
dir.create("plots")
dir.create("tracks")
dir.create("tables")
dir.create("intermediate_cagerobj")

reference_name <- install_bsgenome(bsgenome)

# Read in TxDb object
tx_annotation_obj <- loadDb(tx_annotation)

# Read in CAGEexp object
ce <- readRDS(ce_path)

# plot PCA — extract normalized data
count_mat <- CTSSnormalizedTpmDF(ce)
for (i in 1:ncol(count_mat)) {
    count_mat[, i] <- as.vector(count_mat[, i])
}
count_matmat <- as.matrix(count_mat)

plot_correlation(
    datatype = "norm_CTSS",
    dataframe = CTSSnormalizedTpmDF(ce),
    corrplot_tagCountThreshold = corrplot_tagCountThreshold)
print("Normalized CTSS correlation plotted")

pca_plot <- plot_pcs(count_matmat)
save_plot("CTSS_pca_plot.pdf", pca_plot)
print("CTSS PCA plotted")

# extract tag clusters to GRanges object
sampleNames <- unname(CAGEr::sampleLabels(ce))
tag_clusters <- lapply(
    sampleNames,
    function(x) CAGEr::tagClustersGR(
        ce,
        sample = x,
        qLow = iqlow,
        qUp = iqhigh))
names(tag_clusters) <- sampleNames

# annotate peaks with ChIPseeker
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
            "Downstream", "Intergenic")))

chipannot_plot <- ChIPseeker::plotAnnoBar(peakAnno_list)
save_plot("chipseeker_tagCluster_annotation_plot.pdf", chipannot_plot)

samplename <- names(peakAnno_list)[1]

# Plot sequence distribution at the dominant TSS for each sample
if (abs(tssregion_up - tssregion_down) < 1000) {
    promoter_annot <- "Promoter"
} else if ("Promoter (<=1kb)" %in% peakAnno_list[[samplename]]@annoStat\$Feature) {
    promoter_annot <- "Promoter (<=1kb)"
} else {
    promoter_annot <- "Promoter"
}
for (sample in sampleNames) {
    sample_annotation <- peakAnno_list[[sample]]@anno
    tsslogo_plot <- CAGEr::TSSlogo(
        sample_annotation |> subset(
            sample_annotation@elementMetadata\$annotation == promoter_annot),
        upstream = tsslogo_upstream)
    save_plot(
        paste0(sample, "_tagcluster_dominantTSSlogos_plot.pdf"),
        tsslogo_plot)
}

# dinucleotide composition
weigthed_dinuc_vals_df <- extract_dinucleotide_information(ce, reference_name)
dinuclfreq_plot <- plot_dinucleotide_frequency(weigthed_dinuc_vals_df)
save_plot("dinucleotide_frequencies_plot.pdf", dinuclfreq_plot)

# Consensus clustered CTSS quality plots
consclustTpm <- CAGEr::consensusClustersTpm(ce)
write.table(
    consclustTpm,
    file = "tables/consensus_clusters_tpm.csv",
    quote = FALSE)
print("Consensus cluster tpms saved")

sample_cons_ctss_count <- list()
for (sample in CAGEr::sampleLabels(ce)) {
    sample_cons_ctss_count[[sample]] <- sum(
        as.vector(consclustTpm[, sample]) > 0)
}
sample_cons_ctss_count[["Union"]] <- dim(consclustTpm)[1]
consensus_ctss_plot <- plot_number_of_tag_clusters(
    sample_tag_count = sample_cons_ctss_count,
    yaxistitle = "Number of non-zero consensus clusters",
    mytitle = "Non-zero consensus clusters per sample and union")
save_plot("consensus_counts_plot.pdf", consensus_ctss_plot)
print("Number of non-zero consensus clusters plotted")

pca_plot <- plot_pcs(consclustTpm)
save_plot("consensus_clusters_pca_plot.pdf", pca_plot)
print("Consensus cluster PCA plotted")

versions_yaml <- sprintf(
    '"%s":\n    R: %s\n    CAGEr: %s\n    ChIPseeker: %s\n',
    "${task.process}",
    paste(R.Version()[c("major", "minor")], collapse = "."),
    as.character(packageVersion("CAGEr")),
    as.character(packageVersion("ChIPseeker"))
)
writeLines(versions_yaml, "versions.yml")
