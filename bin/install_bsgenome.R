#
# Install libraries based on input
#

install_bsgenome <- function(bsgenome){

    dir.create(file.path("./r_packages"))
    .libPaths(c("./r_packages", .libPaths()))

    if (endsWith(bsgenome, ".tar.gz")) {
        install.packages(bsgenome, repos = NULL, type = "source")
        reference_name = unlist(strsplit(basename(bsgenome), "_"))[1]
    } else {
        BiocManager::install(bsgenome)
        reference_name = bsgenome
    }

    library(reference_name, character.only = TRUE)

    return(reference_name)
}
