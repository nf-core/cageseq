#' Enhancer calling
#'
#' @param ce initial CAGEexp object with CTSS values
#' @param cfBalanceThreshold threshold for the cagefightr balance score
#' @param unexpressed non-inclusive lower TPM boundary for expression: a TSS with a normalized expression of at most `unexpressed` TPM in a sample is treated as not expressed in that sample
#' @param minSamples minimum number of samples that must support an enhancer (i.e. show bidirectionality, with TSS expression above `unexpressed` TPM on both strands); inclusive, so `minSamples = 1` means at least one sample
#' @return enhancers
#' @examples
#' cagefightr_enhancers(
#' ce,
#' cfBalanceThreshold = 0.95,
#' unexpressed = 0,
#' minSamples = 1
#' )
cagefightr_enhancers <- function(
        ce,
        cfBalanceThreshold,
        unexpressed,
        minSamples){

    # Extract CTSS count matrix as SummarizedExperiment
    se <- CAGEr::CTSStagCountSE(ce)

    # Clean up and structure metadata
    colData(se) <- colData(ce)
    colData(se)$Name <- colData(se)$sampleLabels

    # Convert counts to sparse matrix to save memory
    assays(se, withDimnames=FALSE) <- List(
        counts = as(as.matrix(as.data.frame(assays(se)[[1]])), "dgCMatrix"),
        TPM = as(as.matrix(as.data.frame(assays(se)[[2]])), "dgCMatrix"))

    # Save as main working object
    cfSampleCTSSs <- se

    # Apply the user-defined expression threshold to the normalized TPM values:
    # a TSS with a TPM of at most `unexpressed` in a sample is treated as not
    # expressed in that sample, i.e. its TPM is set to 0 (only values strictly
    # greater than `unexpressed` count as expressed). All following steps work
    # on these thresholded TPM values: the pooled signal that the bidirectional
    # clusters are called on, and the per-sample bidirectionality support. Only
    # the non-zero entries of the sparse matrix need to be visited.
    tpm <- assay(cfSampleCTSSs, "TPM")
    tpm@x[tpm@x <= unexpressed] <- 0
    tpm <- Matrix::drop0(tpm)
    assay(cfSampleCTSSs, "TPM", withDimnames = FALSE) <- tpm
    # Drop the TSSs that are not expressed in any sample after thresholding.
    cfSampleCTSSs <- cfSampleCTSSs[Matrix::rowSums(tpm) > 0, ]

    # Calculate pooled signal across all samples (sum of the TPM values)
    cfSampleCTSSs <- CAGEfightR::calcPooled(
        cfSampleCTSSs,
        inputAssay = "TPM")

    # Find bidirectional clusters (potential enhancers)
    sampleBCs <- CAGEfightR::clusterBidirectionally(
        cfSampleCTSSs,
        balanceThreshold = cfBalanceThreshold)

    # Keep the bidirectional clusters supported in at least `minSamples`
    # samples. A sample supports a cluster if it has TSS expression (thresholded
    # TPM > 0, i.e. TPM > `unexpressed`) on both strands of the cluster.
    # CAGEfightR's own `minSamples` is exclusive (it keeps clusters with a
    # bidirectionality strictly greater than it), so pass `minSamples - 1` to
    # turn the user's inclusive "at least" cutoff into that convention.
    if (minSamples < 0) {
        stop("minSamples must be a non-negative integer, got ", minSamples)
    }
    finalSampleBCs <- CAGEfightR::subsetByBidirectionality(
        sampleBCs,
        samples = cfSampleCTSSs,
        inputAssay = "TPM",
        minSamples = minSamples - 1)

    return(finalSampleBCs)
}

#' Exclude Enhancers Overlapping Promoters
#'
#' This function filters out enhancers from CAGEfightR that overlap with consensus promoters from CAGEr
#'
#' @param BCs A Granges object representing the bidirectional clusters (BCs) from CAGEfightR.
#' @param ce A CAGEexp object from CAGEr containing the consensus clusters.
#'
#' @return A filtered version of the candidate enhancers that do not overlap with the promoters.
#' @export
#'
#' @examples
#' # Example usage:
#' # filtered_enhancers <- exclude_enhancers_overlapping_promoters(promoters, candidate_enhancers)
exclude_enhancers_overlapping_promoters <- function(BCs, ce){
    # remove enhancers that overlap consensus clusters
    promoter_overlaps <- GenomicRanges::findOverlaps(
        query=BCs,
        subject=CAGEr::consensusClustersGR(ce))
    overlapping_idx <- unique(queryHits(promoter_overlaps))
    # Do not use BCs[-overlapping_idx]: in R a negative index of length zero
    # selects nothing, so that form would drop every enhancer whenever none of
    # them overlaps a consensus cluster.
    keep <- rep(TRUE, length(BCs))
    keep[overlapping_idx] <- FALSE
    true_enhancers <- BCs[keep]
    return(true_enhancers)
}

#' Save Enhancer Regions to BED File
#'
#' This function saves a GRanges object of enhancer regions to a BED file.
#'
#' @param enhancers A GRanges object containing enhancer regions.
#' @return None. The function writes the BED track to disk.
#' @export
save_enhancers_to_bed <- function(enhancers){
    # Emit a plain BED6 region track (chrom/start/end/name/score/strand); the
    # richer per-enhancer attributes remain in the exported tables and RDS.
    gr <- methods::as(enhancers, "GRanges")
    keep <- intersect(c("name", "score"), names(S4Vectors::mcols(gr)))
    S4Vectors::mcols(gr) <- S4Vectors::mcols(gr)[, keep, drop = FALSE]
    rtracklayer::export.bed(gr, 'tracks/enhancers.bed')
}

#' Annotate Enhancers with Transcript Database Information
#'
#' This function annotates a set of enhancers with information from a given transcript database.
#'
#' @param enhancers A data frame or GRanges object representing the enhancers to be annotated.
#' @param txdb A TxDb object containing transcript database information to be used for annotation.
#'
#' @return A data frame or GRanges object with the annotated enhancer information.
#' @export
#'
#' @examples
#' # Example usage:
#' # annotated_enhancers <- annotate_enhancers(enhancers, txdb)
annotate_enhancers <- function(
        enhancers,
        txdb,
        tssregion_up,
        tssregion_down){
    enhancerAnno <- ChIPseeker::annotatePeak(
        enhancers,
        TxDb = txdb,
        tssRegion = c(tssregion_up, tssregion_down),
        sameStrand = FALSE,
        level = "transcript",
        genomicAnnotationPriority = c(
            "Promoter", "5UTR", "3UTR",
            "Exon", "Intron",
            "Downstream", "Intergenic"))
    chipannot_plot <- ChIPseeker::plotAnnoBar(enhancerAnno)
    save_plot(
        "chipseeker_enhancer_annotation_plot.pdf",
        chipannot_plot
    )
}

#' Identify Sample-Specific Enhancers
#'
#' This function identifies sample-specific enhancers and their TPMs by comparing
#' a set of enhancers with CTSS from CAGEr
#'
#' @param true_enhancers GRanges object representing the enhancers to be compared.
#' @param ce CAGEexp object containing the sample-specific normalized CTSS data.
#'
#' @return A data frame with rows as ranges, and columns as samples, containing the TPM values for each enhancer.
#' @export
#'
identify_sample_specific_enhancers <- function(true_enhancers, ce){
    # for each sample, check the overlap between bidirectional clusters
    # and normalized CTSS counts

    # save expression per sample for each region
    enhancer_expr_per_sample <- data.frame(row.names=names(true_enhancers))

    for (sample in CAGEr::sampleLabels(ce)){
        ctss <- CAGEr::CTSSnormalizedTpmGR(ce, sample=sample)
        overlap <- GenomicRanges::findOverlaps(
            query = true_enhancers,
            subject = ctss)
        enhancer_ctss_scores <- extractList(score(ctss), overlap)
        enhancer_sample_vector <- numeric(length(enhancer_ctss_scores))
        for (i in seq_along(enhancer_ctss_scores)) {
            enhancer_sample_vector[i] <- sum(as.numeric(enhancer_ctss_scores[[i]]))
        }
        enhancer_expr_per_sample[sample] <- enhancer_sample_vector
    }
    return(enhancer_expr_per_sample)
}

#' Count Number of Enhancers Per Sample
#'
#' This function counts the number of enhancers expressed in each sample based on the enhancer expression matrix.
#'
#' @param enhancer_expr_per_sample A data frame where rows represent enhancers and columns represent samples, containing expression values.
#'
#' @return A named list where each element corresponds to a sample and contains the count of expressed enhancers.
#' @export
#'
#' @examples
#' # Example usage:
#' # enhancer_counts <- count_number_of_enhancers(enhancer_expr_per_sample)
count_number_of_enhancers <- function(enhancer_expr_per_sample) {
    sample_enhancer_count <- list()
    for (sample in colnames(enhancer_expr_per_sample)) {
        sample_enhancer_count[[sample]] <- sum(as.vector(enhancer_expr_per_sample[,sample]) > 0)
    }
    sample_enhancer_count[["Union"]] <- dim(enhancer_expr_per_sample)[1]
    return(sample_enhancer_count)
}
