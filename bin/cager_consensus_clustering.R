#' Extract CTSS score per sample per region

overlapper <- function(ce, sample){
    ctss <- CAGEr::CTSSnormalizedTpmGR(ce, sample=sample)
    overlap <- GenomicRanges::findOverlaps(
            query = consensusClustersGR(ce),
            subject = ctss)
    grouped_scores <- extractList(score(ctss), overlap)
    return(grouped_scores)
}

sum_scores_per_location <- function(scores){
    # sum values
    result_vector <- numeric(length(scores))
    # Loop through each element and add the value at the correct position
    for (i in seq_along(scores)) {
        result_vector[i] <- sum(as.numeric(scores[[i]]))
    }
    return(result_vector)
}

# Replace scores in consensus clusters with the sum of normalized CTSS scores
score_from_ctss <- function(ce){
    # use normalized CTSS to calculate and update score
    ctss_score_df <- data.frame(names = names(consensusClustersGR(ce)))
    sample_sum <- 0

    for (sample in CAGEr::sampleLabels(ce)){
        new_scores <- overlapper(ce, sample)
        ctss_score_df[[sample]] <- sum_scores_per_location(new_scores)
        sample_sum <- sample_sum + ctss_score_df[[sample]]
    }

    write.csv(
        ctss_score_df,
        "tables/consensus_cluster_per_sample_ctss.csv",
        row.names = FALSE,
        quote = FALSE)

    # Convert to Rle and assign to consensus cluster
    # add to a new column called ctss_score
    elementMetadata(consensusClustersGR(ce))[["ctss_score"]] <- Rle(sample_sum)

    return(ce)
}

#' Consensus clustering of CTSS across samples
#'
#' @param ce normalized CAGEexp object
#' @param tpmThreshold Threshold for calling consensus clusters (in aggregateTagClusters function)
#' @param maxDist Maximum distance for calling consensus clusters (in aggregateTagClusters function)
#' @param tx_annotation SQLite file with a TxDb genome annotation package
#' @return ce clustered CAGEexp object
#' @examples
#' consensus_clustering(
#' ce,
#' tpmThreshold = 5,
#' maxDist = 100,
#' tx_annotation = "annotation_from_gtf.sqlite",
#' num_core = 4)

consensus_clustering <- function(
        ce,
        tpmThreshold,
        maxDist,
        tx_annotation,
        num_core,
        iqlow,
        iqhigh){

    multicore <- TRUE
    if(num_core < 2){
        multicore <- FALSE
        num_core <- NULL
    }

    ce <- CAGEr::aggregateTagClusters(
        ce,
        tpmThreshold = tpmThreshold,
        qLow = iqlow,
        qUp = iqhigh,
        maxDist = maxDist)

    ce <- score_from_ctss(ce)

    # Read in TxDb object
    tx_annotation_obj <- loadDb(tx_annotation)
    ce <- annotateConsensusClusters(
        ce,
        tx_annotation_obj)

    ce <- CAGEr::cumulativeCTSSdistribution(
        ce,
        clusters = "consensusClusters",
        useMulticore = multicore,
        nrCores = num_core)
    ce <- CAGEr::quantilePositions(
        ce,
        clusters = "consensusClusters",
        qLow = iqlow,
        qUp = iqhigh,
        useMulticore = multicore,
        nrCores = num_core)

    return(ce)
}
