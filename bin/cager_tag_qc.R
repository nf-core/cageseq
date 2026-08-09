#!/usr/bin/env Rscript

#
# Initial quality control of CAGE reads
#


# Load libraries
required.libraries <- c(
    "optparse",
    "CAGEr",
    "GenomicFeatures",
    "gplots",
    "ggplot2",
    "ggseqlogo")

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
        c("-a", "--annotation"),
        type = "character",
        default = NULL,
        help = "SQLite file with a TxDb genome annotation package (Mandatory)"),
    make_option(
        c("-b", "--bsgenome"),
        type = "character",
        default = NULL,
        help = "Name of the BSgenome version to be used (Mandatory)"),
    make_option(
        c("-t", "--corrplot_tagCountThreshold"),
        type = "integer",
        default = 1,
        help = "Threshold for considering tags when calculating correlations (Default = 1)"),
    make_option(
        c("-p", "--project_dir"),
        type = "character",
        default = NULL,
        help = "Project directory, from which the analysis is run.")
)

message("; Reading arguments from command line.")
opt_parser = optparse::OptionParser(option_list = option_list)
opt = optparse::parse_args(opt_parser)

# set variable names
ce_path         <- opt$cageexp_object
tx_annotation   <- opt$annotation
bsgenome        <- opt$bsgenome
corrplot_tagCountThreshold <- opt$corrplot_tagCountThreshold
project_dir     <- opt$project_dir

# installing BSgenome
source(file.path(project_dir, "bin/install_bsgenome.R"))
# import functions for quality control and plotting
source(file.path(project_dir, "bin/plot_saving.R"))
source(file.path(project_dir, "bin/qc_plots.R"))

reference_name <- install_bsgenome(bsgenome)

# Create folders for organized analysis
dir.create(file.path("plots"))
dir.create(file.path("tracks"))
dir.create(file.path("tables"))
dir.create(file.path("intermediate_cagerobj"))

print("Reading in CAGEexp object...")
# Read in CAGEexp object
ce <- readRDS(ce_path)

print("Reading in TxDb object...")
# Read in TxDb object
tx_annotation_obj <- loadDb(tx_annotation)

print("Annotating CTSS...")
ce <- CAGEr::annotateCTSS(ce, tx_annotation_obj)

# annotateCTSS tallies the per-sample tag counts of each annotation class with
# tapply() over a factor whose levels are fixed (promoter/exon/intron/unknown).
# A class that no CTSS falls into gets NA rather than the 0 it stands for. That
# NA is not harmless: plotAnnot(ce, "counts") derives the intergenic segment by
# subtraction (librarySizes - promoter - intron - exon), so a single missing
# class turns BOTH that class and the intergenic segment into NA and the stacked
# bars silently stop short of 1.00. Replace the missing tallies with zeroes
# before the object is saved, so every downstream consumer sees them too.
annotation_classes <- intersect(
    levels(CAGEr::CTSScoordinatesGR(ce)$annotation),
    colnames(colData(ce)))
for (annotation_class in annotation_classes) {
    class_counts <- colData(ce)[[annotation_class]]
    if (anyNA(class_counts)) {
        message(
            "; No CTSS annotated as \"", annotation_class,
            "\" in ", sum(is.na(class_counts)),
            " sample(s); recording the count as 0.")
        class_counts[is.na(class_counts)] <- 0
        colData(ce)[[annotation_class]] <- class_counts
    }
}

# Save intermediate annotated object
saveRDS(ce, "intermediate_cagerobj/annotated_cagexp.rds")

print("Plotting annotations...")

annotations <- CAGEr::plotAnnot(ce, "counts")
save_plot(
    "tag_region_annotation_plot.pdf",
    annotations
)

# to compare raw counts CTSStagCountDF is used
# bypassing the automatic selection of this assay
# uses function from qc_plots.R

plot_correlation(
    datatype="CTSS",
    dataframe=CTSStagCountDF(ce),
    corrplot_tagCountThreshold=corrplot_tagCountThreshold)
print("CTSS correlation plotted")
