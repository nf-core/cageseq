#!/usr/bin/env Rscript

#
# Script to read in data to CAGEr from BAM or BigWig format
#

suppressPackageStartupMessages({
    library(BSgenome)
    library(CAGEr)
    library(stringr)
    library(purrr)
    library(dplyr)
    library(tidyr)
    library(magrittr)
})

# Variables injected by Nextflow
data_type         <- "${data_type}"
sample_table_list <- "${sample_table}"
bsgenome_name     <- "${bsgenome_name}"
bsgenome_file     <- "${bsgenome_file}"
num_core          <- as.integer(${task.cpus})

bsgenome <- if (nchar(trimws(bsgenome_name)) > 0) bsgenome_name else bsgenome_file

# Import helper functions
source("${projectDir}/bin/install_bsgenome.R")
source("${projectDir}/bin/parse_input.R")

# Create folders for organized analysis
dir.create("plots")
dir.create("tracks")
dir.create("tables")
dir.create("intermediate_cagerobj")

print(paste0("Using reference genome: ", bsgenome))

reference_name <- install_bsgenome(bsgenome)

print(paste0("Reading in ", data_type, " files..."))

sample_table <- parse_input(sample_table_list, data_type)
single_end_uniq <- unique(sample_table\$single_end)
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
sample_idx_to_remove = which(sample_table\$new_name == " ")
if (length(sample_idx_to_remove) > 0) {
    print("Removing samples with empty new names:")
    print(sample_table[sample_idx_to_remove, ])
    keep         = -sample_idx_to_remove
    new_names    = stringr::str_squish(sample_table\$new_name[keep])
    sample_names = stringr::str_squish(sample_table\$id[keep])
    sample_paths = stringr::str_squish(sample_table\$path[keep])
} else {
    print("No samples with empty new names found.")
    keep         = seq_len(nrow(sample_table))
    new_names    = stringr::str_squish(sample_table\$new_name)
    sample_names = stringr::str_squish(sample_table\$id)
    sample_paths = stringr::str_squish(sample_table\$path)
}

merge_labels <- function(sample_names, new_names, ce) {
    name_df = data.frame(
        sample_name = sample_names,
        new_name = new_names)
    name_df = name_df[order(name_df\$new_name), ]
    name_df\$merge_idx = match(name_df\$new_name, unique(name_df\$new_name))
    merged_sample_labels = unique(name_df\$new_name)
    name_df = name_df[match(CAGEr::sampleLabels(ce), name_df\$sample_name), ]
    ce <- CAGEr::mergeSamples(
        ce,
        mergeIndex = name_df\$merge_idx,
        mergedSampleLabels = merged_sample_labels)
    return(ce)
}

multicore <- TRUE
if (num_core < 2) {
    multicore <- FALSE
    num_core <- NULL
}

if (tolower(data_type) == "bam") {
    ce <- CAGEr::CAGEexp(
        genomeName     = reference_name,
        inputFiles     = sample_paths,
        inputFilesType = bam_type,
        sampleLabels   = sample_names)
} else if (tolower(data_type) == "bigwig") {
    str1_paths = stringr::str_squish(sample_table\$path1[keep])
    ce <- CAGEexp(
        genomeName     = reference_name,
        inputFiles     = str1_paths,
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

# Merge if necessary
if (any(sample_names != new_names)) {
    print("Merging samples according to new names")
    ce <- merge_labels(sample_names, new_names, ce)
} else {
    print("No merging performed.")
}

saveRDS(ce, "intermediate_cagerobj/initial_cagexp.rds")

versions_yaml <- sprintf(
    '"%s":\n    R: %s\n    CAGEr: %s\n    BSgenome: %s\n',
    "${task.process}",
    paste(R.Version()[c("major", "minor")], collapse = "."),
    as.character(packageVersion("CAGEr")),
    as.character(packageVersion("BSgenome"))
)
writeLines(versions_yaml, "versions.yml")
