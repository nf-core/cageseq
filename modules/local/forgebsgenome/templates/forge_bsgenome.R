#!/usr/bin/env Rscript

library(BSgenome)

# forgeBSgenomeDataPkg delegates 2bit writing to the UCSC C library, which does
# not create intermediate directories itself. Pre-create inst/extdata/ so that
# the write succeeds.
seed_lines <- readLines("${forge_seed}")
pkg_name <- trimws(strsplit(seed_lines[grep("^Package:", seed_lines)], ":")[[1]][2])
dir.create(file.path(pkg_name, "inst", "extdata"), recursive = TRUE, showWarnings = FALSE)

forgeBSgenomeDataPkg(
    "${forge_seed}",
    ".",
    replace = TRUE)

pkg_name <- strsplit(readLines("${forge_seed}")[1], " ")[[1]][2]
system(paste("R CMD build", pkg_name))
system(paste0("R CMD check ", pkg_name, "*.tar.gz --no-manual"))

# Collect versions
r_version <- paste(R.Version()[c("major", "minor")], collapse = ".")
bsgenome_version <- as.character(packageVersion("BSgenome"))

versions_yaml <- sprintf(
    '"%s":\n    R: %s\n    BSgenome: %s\n',
    "${task.process}",
    r_version,
    bsgenome_version
)

writeLines(versions_yaml, "versions.yml")
