#!/usr/bin/env Rscript

#
# Script to read in data to CAGEr from BAM or BigWig format
#

# Load libraries
required.libraries <- c(
    "optparse",
    "BSgenome",
    "CAGEr",
    "stringr",
    "purrr",
    "dplyr",
    "tidyr",
    "magrittr"
)

for (lib in required.libraries) {
    suppressPackageStartupMessages(library(lib, character.only=TRUE, quietly = T))
}

# parse options
option_list = list(
    make_option(
        c("-t", "--data_type"),
        type = "character",
        default = NULL,
        help = "Whether BAM (bam) or BigWig (bigwig) is provided (Mandatory)"),
    make_option(
        c("-s", "--sample_table_list"),
        type = "character",
        default = NULL,
        help = "Csv with information from the input channel with [id, pairedness, bigwig or bam path, new name] (Mandatory)"),
    make_option(
        c("-b", "--bsgenome"),
        type = "character",
        default = NULL,
        help = "Name of the BSgenome version to be used (Mandatory)"),
    make_option(
        c("-o", "--sort_samples"),
        type = "character",
        default = "false",
        help = "If 'true', samples are put in natural order (S1, S2, ..., S10); otherwise they keep the order of the sample list (Default = false)"),
    make_option(
        c("-p", "--project_dir"),
        type = "character",
        default = NULL,
        help = "Project directory, from which the analysis is run. (Mandatory)"),
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
data_type           <- opt$data_type
sample_table_list   <- opt$sample_table_list
sort_samples        <- tolower(as.character(opt$sort_samples)) %in% c("true", "t", "yes", "1")
bsgenome            <- opt$bsgenome
project_dir         <- opt$project_dir
num_core            <- opt$num_core

# import functions

# installing BSgenome
source(file.path(project_dir, "bin/install_bsgenome.R"))
# reading in bam / bigwig data
source(file.path(project_dir, "bin/parse_input.R"))
# sample ordering helpers
source(file.path(project_dir, "bin/sample_order.R"))

# Create folders for organized analysis
dir.create(file.path("plots"))
dir.create(file.path("tracks"))
dir.create(file.path("tables"))
dir.create(file.path("intermediate_cagerobj"))

print(paste0("Using reference genome: ", bsgenome))

reference_name <- install_bsgenome(bsgenome)

print(paste0("Reading in ", data_type, " files..."))

sample_table <- parse_input(sample_table_list, data_type)
single_end_uniq <- unique(sample_table$single_end)
if (length(single_end_uniq) < 1) {
    print(sample_table)
    stop("Sample table is empty or the header is missing.")
} else if (length(single_end_uniq) > 1) {
    print(sample_table)
    stop("Sample table contains both single-end and paired-end reads.")
} else {
    bam_type <- ifelse(
        trimws(single_end_uniq) == "true",
        "bam",
        "bamPairedEnd")
}

# remove samples with empty new names
sample_idx_to_remove = which(sample_table$new_name == " ")
if (length(sample_idx_to_remove) > 0) {
    print("Removing samples with empty new names:")
    print(sample_table[sample_idx_to_remove, ])
    new_names = stringr::str_squish(sample_table$new_name[-sample_idx_to_remove])
    sample_names = stringr::str_squish(sample_table$id[-sample_idx_to_remove])
    sample_paths = stringr::str_squish(sample_table$path[-sample_idx_to_remove])
} else {
    print("No samples with empty new names found.")
    new_names = stringr::str_squish(sample_table$new_name)
    sample_names = stringr::str_squish(sample_table$id)
    sample_paths = stringr::str_squish(sample_table$path)
}

#' Merge and Rename Samples in a CAGEr Object
#'
#' Merges or renames samples in a CAGEr object according to user-specified new names.
#'
#' @param sample_names Character vector of original sample names.
#' @param new_names Character vector of new sample names (after merging/renaming).
#' @param ce A CAGEr::CAGEexp object.
#'
#' @return A CAGEr::CAGEexp object with merged/renamed samples.
#' @importFrom CAGEr sampleLabels mergeSamples
#' @export
merge_labels <- function(sample_names, new_names, ce, sort_samples = FALSE) {
    # merge / rename samples according to user's instructions (new_names)
    # make it a function to call for both bams and bigwigs.
    # The merged labels keep the order of first appearance in the user's sample
    # list, unless sort_samples is TRUE, in which case they are put in natural
    # order; this order becomes the sample order of the CAGEexp object.
    merged_sample_labels = unique(new_names)
    if (sort_samples) {
        merged_sample_labels = natural_sort(merged_sample_labels)
    }
    name_df = data.frame(
        sample_name = sample_names,
        new_name = new_names)
    name_df$merge_idx = match(name_df$new_name, merged_sample_labels)
    name_df = name_df[match(CAGEr::sampleLabels(ce), name_df$sample_name), ]
    ce <- CAGEr::mergeSamples(
        ce,
        mergeIndex = name_df$merge_idx,
        mergedSampleLabels = merged_sample_labels)
    return(ce)
}

multicore <- TRUE
if(num_core < 2){
    multicore <- FALSE
    num_core <- NULL
}

if (tolower(data_type) == "bam"){
    ce <- CAGEr::CAGEexp(
        genomeName     = reference_name,
        inputFiles         = sample_paths,
        inputFilesType     = bam_type,
        sampleLabels       = sample_names)
} else if(tolower(data_type) == "bigwig") {
    bigwigs = unlist(
        stringr::str_split(
            stringr::str_remove_all(
                sample_paths, ","),
            stringr::fixed(" ")))
    # Create a CAGEexp object, filenames only of str1
    ce <- CAGEexp(
        genomeName     = reference_name,
        inputFiles     = bigwigs[grep("str1", bigwigs)],
        inputFilesType = "bigwig",
        sampleLabels   = sample_names)
} else {
    stop("Either bigwig or bam files should be provided")
}

# Read in samples
ce <- CAGEr::getCTSS(
    ce,
    removeFirstG = F,
    correctSystematicG = F,
    useMulticore = multicore,
    nrCores = num_core)

# Merge if necessary (also used to put the samples in natural order when
# sort_samples is TRUE, through an identity merge)
if (sort_samples || any(sample_names != new_names)) {
    print("Merging / ordering samples according to new names")
    ce <- merge_labels(sample_names, new_names, ce, sort_samples = sort_samples)
} else {
    print("No merging performed.")
}
print(paste0("Sample order in the CAGEexp object: ", paste(CAGEr::sampleLabels(ce), collapse = ", ")))

# save the initial CAGEexp object
saveRDS(ce, "intermediate_cagerobj/initial_cagexp.rds")
