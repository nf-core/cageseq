#!/usr/bin/env Rscript

#
# Script to convert GTF into TxDb object
#

suppressPackageStartupMessages(library(txdbmaker, quietly = TRUE))

txdb <- makeTxDbFromGFF("${gtf}")
saveDb(txdb, "annotation_from_gtf.sqlite")

# Collect versions
r_version <- paste(R.Version()[c("major", "minor")], collapse = ".")
txdbmaker_version <- as.character(packageVersion("txdbmaker"))

versions_yaml <- sprintf(
    '"%s":\n    R: %s\n    txdbmaker: %s\n',
    "${task.process}",
    r_version,
    txdbmaker_version
)

writeLines(versions_yaml, "versions.yml")
