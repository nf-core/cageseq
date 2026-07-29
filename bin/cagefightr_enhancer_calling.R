#!/usr/bin/env Rscript

# #
# # Call enhancers with CAGEfightR
# #

# # Load libraries
required.libraries <- c(
    "optparse",
    "CAGEr",
    "CAGEfightR",
    "GenomicRanges",
    "GenomicFeatures",
    "dplyr",
    "rtracklayer",
    "ggplot2",
    "ggrepel"
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
        help = "Path to the CAGEexp object with normalized tags and consensus clusters (Mandatory)"),
    make_option(
        c("-x", "--annotation"),
        type = "character",
        default = NULL,
        help = "SQLite file with a TxDb genome annotation package (Mandatory)"),
    make_option(
        c("-b", "--cfBalanceThreshold"),
        type = "double",
        default = 0.95,
        help = "threshold for the cagefightr balance score (Default=0.95)"),
    make_option(
        c("-e", "--unexpressed"),
        type = "double",
        default = 0,
        help = "threshold above which normalized CTSS are considered expressed (Default=0)"),
    make_option(
        c("-s", "--minSamples"),
        type = "integer",
        default = 0,
        help = "non inlcusive lower threshold for number of samples supporting enhancers (i.e. where there is bidirectionality) (Default=0)"),
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
        c("-p", "--project_dir"),
        type = "character",
        default = 0,
        help = "Project directory, from which the analysis is run.")
)

message("; Reading arguments from command line.")
opt_parser = optparse::OptionParser(option_list = option_list)
opt = optparse::parse_args(opt_parser)

# set variable names
ce_path             <- opt$cageexp_object
tx_annotation       <- opt$annotation
cfBalanceThreshold  <- opt$cfBalanceThreshold
unexpressed         <- opt$unexpressed
minSamples        <- opt$minSamples
tssregion_up    <- opt$tssregion_up
tssregion_down  <- opt$tssregion_down
project_dir         <- opt$project_dir

# import functions
# installing BSgenome
source(file.path(project_dir, "bin/install_bsgenome.R"))
# for analysis
source(file.path(project_dir, "bin/enhancer_functions.R"))
source(file.path(project_dir, "bin/qc_plots.R"))
source(file.path(project_dir, "bin/plot_saving.R"))

# Create folders for organized analysis
dir.create(file.path("plots"))
dir.create(file.path("tracks"))
dir.create(file.path("tables"))
dir.create(file.path("intermediate_cagerobj"))

# Read in CAGEexp object
ce <- readRDS(ce_path)

# annotate enhancers with transcript database information
tx_annotation_obj <- loadDb(tx_annotation)
print("Annotation in TxDb is loaded")

# save enhancer expression per sample
outFileNameSamples <- file.path(
    "tables", "enhancer_expression_per_sample.tsv")

# The three enhancer-related plots that the CAGEr report expects to exist.
enhancer_plot_files <- c(
    "chipseeker_enhancer_annotation_plot.pdf",
    "enhancer_expression_pca_plot.pdf",
    "enhancer_count_per_sample_plot.pdf")

# Put the same placeholder plot (bearing the given message) in place of every
# enhancer plot so the report can still be rendered.
write_enhancer_placeholders <- function(message) {
    for (plot_file in enhancer_plot_files) {
        save_plot(plot_file, make_message_plot(message))
    }
}

# The module output contract requires the enhancer rds objects, the per-sample
# expression table and a BED track to be present even when no enhancers are
# called or an error occurred. Create empty stand-ins for whatever is missing so
# Nextflow can collect the outputs and the pipeline continues to the report.
ensure_enhancer_stub_files <- function() {
    for (rds_file in c(
        "intermediate_cagerobj/supported_enhancers.rds",
        "intermediate_cagerobj/nonTSS_enhancers.rds")) {
        if (!file.exists(rds_file)) {
            saveRDS(NULL, file = rds_file)
        }
    }
    if (!file.exists(outFileNameSamples)) {
        file.create(outFileNameSamples)
    }
    if (length(list.files("tracks", pattern = "\\.bed$")) == 0) {
        file.create(file.path("tracks", "enhancers.bed"))
    }
}

# Call enhancers and run the full downstream analysis. Any failure along the way
# is captured so that, instead of crashing the pipeline, the error is logged to a
# published text file and an "Error occurred when calling enhancers" placeholder
# is shown in the report. If enhancer calling succeeds but finds no enhancers,
# a "No enhancers called" placeholder is shown instead.
enhancer_status <- tryCatch({

    # call enhancers with CAGEfightR
    supported_enhancers <- cagefightr_enhancers(
        ce=ce,
        cfBalanceThreshold=cfBalanceThreshold,
        unexpressed=unexpressed,
        minSamples=minSamples)

    saveRDS(supported_enhancers, file = "intermediate_cagerobj/supported_enhancers.rds")
    print("Supported enhancers rds file saved")

    # exclude enhancers overlapping promoters defined by consensus clusters
    true_enhancers <- exclude_enhancers_overlapping_promoters(
        BCs=supported_enhancers,
        ce=ce)
    print("Enhancers overlapping promoters excluded")

    saveRDS(true_enhancers, file = "intermediate_cagerobj/nonTSS_enhancers.rds")
    print("Enhancers excluding promoters (consensus clusters) rds file saved")

    if (length(true_enhancers) > 0) {

        annotate_enhancers(
            enhancers=true_enhancers,
            txdb=tx_annotation_obj,
            tssregion_up=tssregion_up,
            tssregion_down=tssregion_down)

        print("Enhancers annotated")

        print("Saving enhancers to BED files...")
        save_enhancers_to_bed(enhancers=true_enhancers)
        print("Enhancers saved to BED files")

        # assign enhancers to samples
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

        # plot PCA of enhancer expression per sample
        pca_plot <- plot_pcs(
            count_matrix=enhancer_expr_per_sample)
        save_plot(
            "enhancer_expression_pca_plot.pdf",
            pca_plot)
        print("PCA plot of enhancer expression per sample saved")

        # count and plot number of enhancers per sample
        sample_enhancer_count <- count_number_of_enhancers(
            enhancer_expr_per_sample=enhancer_expr_per_sample)
        # function from qc_plots.R
        enhancer_count_plot <- plot_number_of_tag_clusters(
            sample_tag_count=sample_enhancer_count,
            yaxistitle="Number of enhancers per sample",
            mytitle="Number of enhancers per sample",
            myfilename="enhancer_count_per_sample")
        save_plot(
            "enhancer_count_per_sample_plot.pdf",
            enhancer_count_plot)
        print("Enhancer counts plotted")

        "found"

    } else {
        "none"
    }

}, error = function(e) {
    message("Enhancer calling failed: ", conditionMessage(e))
    save_error_log("enhancer_calling_error.txt", e)
    "error"
})

if (enhancer_status == "none") {
    print("No enhancers called; writing placeholder plots")
    write_enhancer_placeholders("No enhancers called")
} else if (enhancer_status == "error") {
    print("Enhancer calling errored; writing placeholder plots")
    write_enhancer_placeholders("Error occurred when calling enhancers")
}

# Make sure the non-plot outputs declared by the module always exist.
ensure_enhancer_stub_files()
