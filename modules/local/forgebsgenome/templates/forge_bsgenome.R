#!/usr/bin/env Rscript

library(BSgenome)

forgeBSgenomeDataPkg(
    "${forge_seed}",
    ".")

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
