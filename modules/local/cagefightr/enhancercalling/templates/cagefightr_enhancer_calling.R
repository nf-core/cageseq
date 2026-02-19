#!/usr/bin/env Rscript

# Call enhancers with CAGEfightR

suppressPackageStartupMessages({
    library(CAGEr)
    library(CAGEfightR)
    library(GenomicRanges)
    library(GenomicFeatures)
    library(dplyr)
    library(rtracklayer)
    library(ggplot2)
    library(ggrepel)
})

# Source helper functions
source("${projectDir}/bin/install_bsgenome.R")
source("${projectDir}/bin/enhancer_functions.R")
source("${projectDir}/bin/qc_plots.R")
source("${projectDir}/bin/plot_saving.R")

# Variables injected by Nextflow
ce_path            <- "${cager_obj}"
tx_annotation      <- "${txdb}"
cfBalanceThreshold <- ${params.cfBalanceThreshold}
unexpressed        <- ${params.unexpressed}
minSamples         <- as.integer(${params.minSamples})
tssregion_up       <- as.integer(${params.tssregion_up})
tssregion_down     <- as.integer(${params.tssregion_down})

# Create output folders
dir.create("plots")
dir.create("tracks")
dir.create("tables")
dir.create("intermediate_cagerobj")

# Read in CAGEexp object
ce <- readRDS(ce_path)

# Call enhancers with CAGEfightR
supported_enhancers <- cagefightr_enhancers(
    ce=ce,
    cfBalanceThreshold=cfBalanceThreshold,
    unexpressed=unexpressed,
    minSamples=minSamples)

saveRDS(supported_enhancers, file = "intermediate_cagerobj/supported_enhancers.rds")
print("Supported enhancers rds file saved")

# Exclude enhancers overlapping promoters defined by consensus clusters
true_enhancers <- exclude_enhancers_overlapping_promoters(
    BCs=supported_enhancers,
    ce=ce)
print("Enhancers overlapping promoters excluded")

# Load transcript database
tx_annotation_obj <- loadDb(tx_annotation)
print("Annotation in TxDb is loaded")

outFileNameSamples <- file.path("tables", "enhancer_expression_per_sample.tsv")

if (length(true_enhancers) > 0) {

    annotate_enhancers(
        enhancers=true_enhancers,
        txdb=tx_annotation_obj,
        tssregion_up=tssregion_up,
        tssregion_down=tssregion_down)
    print("Enhancers annotated")

    saveRDS(true_enhancers, file = "intermediate_cagerobj/nonTSS_enhancers.rds")
    print("Enhancers excluding promoters (consensus clusters) rds file saved")

    print("Saving enhancers to bed file...")
    save_enhancers_to_bed(enhancers=true_enhancers)
    print("Enhancers saved to BED file")

    enhancer_expr_per_sample <- identify_sample_specific_enhancers(
        true_enhancers=true_enhancers,
        ce=ce)
    print("Enhancers assigned to samples")

    write.table(
        enhancer_expr_per_sample,
        file=outFileNameSamples,
        quote=FALSE,
        sep='\t')
    print("Enhancer expressions per sample saved to file")

    pca_plot <- plot_pcs(count_matrix=enhancer_expr_per_sample)
    save_plot("enhancer_expression_pca_plot.pdf", pca_plot)
    print("PCA plot of enhancer expression per sample saved")

    sample_enhancer_count <- count_number_of_enhancers(
        enhancer_expr_per_sample=enhancer_expr_per_sample)
    enhancer_count_plot <- plot_number_of_tag_clusters(
        sample_tag_count=sample_enhancer_count,
        yaxistitle="Number of enhancers per sample",
        mytitle="Number of enhancers per sample",
        myfilename="enhancer_count_per_sample")
    save_plot("enhancer_count_per_sample_plot.pdf", enhancer_count_plot)
    print("Enhancer counts plotted")

} else {

    chipannot_empty_plot <- make_no_enhancer_plot()
    save_plot("chipseeker_enhancer_annotation_plot.pdf", chipannot_empty_plot)

    file.create(outFileNameSamples)

    pca_empty_plot <- make_no_enhancer_plot()
    save_plot("enhancer_expression_pca_plot.pdf", pca_empty_plot)

    enhancer_count_empty_plot <- make_no_enhancer_plot()
    save_plot("enhancer_count_per_sample_plot.pdf", enhancer_count_empty_plot)
}

# Write versions
versions_yaml <- sprintf(
    '"%s":\n    R: %s\n    CAGEfightR: %s\n',
    "${task.process}",
    paste(R.Version()[c("major", "minor")], collapse = "."),
    as.character(packageVersion("CAGEfightR"))
)
writeLines(versions_yaml, "versions.yml")
