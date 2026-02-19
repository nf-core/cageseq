#!/usr/bin/env Rscript

library(BSgenome)

forgeBSgenomeDataPkg(
    "${forge_seed}",
    ".")

pkg_name <- strsplit(readLines("${forge_seed}")[1], " ")[[1]][2]
system(paste("R CMD build", pkg_name))
system(paste0("R CMD check ", pkg_name, "*.tar.gz --no-manual"))
