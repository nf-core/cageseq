#!/usr/bin/env Rscript

#
# Initial quality control of CAGE reads
#

suppressPackageStartupMessages({
    library(CAGEr)
    library(GenomicFeatures)
    library(gplots)
    library(ggplot2)
    library(ggseqlogo)
})

# Variables injected by Nextflow
ce_path                    <- "${cager_obj}"
tx_annotation              <- "${txdb}"
bsgenome_name              <- "${bsgenome_name}"
bsgenome_file              <- "${bsgenome_file}"
corrplot_tagCountThreshold <- as.integer(${params.corrplot_tagCountThreshold})

bsgenome <- if (nchar(trimws(bsgenome_name)) > 0) bsgenome_name else bsgenome_file

# Import helper functions
source("${projectDir}/bin/install_bsgenome.R")
source("${projectDir}/bin/plot_saving.R")
source("${projectDir}/bin/qc_plots.R")

reference_name <- install_bsgenome(bsgenome)

# Create folders for organized analysis
dir.create("plots")
dir.create("tracks")
dir.create("tables")
dir.create("intermediate_cagerobj")

print("Reading in CAGEexp object...")
ce <- readRDS(ce_path)

print("Reading in TxDb object...")
tx_annotation_obj <- loadDb(tx_annotation)

print("Annotating CTSS...")
ce <- CAGEr::annotateCTSS(ce, tx_annotation_obj)

saveRDS(ce, "intermediate_cagerobj/annotated_cagexp.rds")

print("Plotting annotations...")
annotations <- CAGEr::plotAnnot(ce, "counts")
save_plot("tag_region_annotation_plot.pdf", annotations)

plot_correlation(
    datatype = "CTSS",
    dataframe = CTSStagCountDF(ce),
    corrplot_tagCountThreshold = corrplot_tagCountThreshold)
print("CTSS correlation plotted")

versions_yaml <- sprintf(
    '"%s":\n    R: %s\n    CAGEr: %s\n',
    "${task.process}",
    paste(R.Version()[c("major", "minor")], collapse = "."),
    as.character(packageVersion("CAGEr"))
)
writeLines(versions_yaml, "versions.yml")
