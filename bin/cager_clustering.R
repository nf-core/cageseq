#' Clustering tags
#'
#' @param ce normalized CAGEexp object
#' @param iqw_plot_lim Limits to IQ width plot x axis
#' @param sample_num_thr Threshold for nr of samples where tpm should be higher during filtering low expressed TSS before tag clustering
#' @param ctss_thr Tpm threshold for filtering low expressed TSS before tag clustering
#' @param distclu_maxDist maximum distance parameter for distclu CAGEr function
#' @param keepSingletonsAbove threshold above which to keep the singletons during tag clustering
#' @param iqw_tpm_threshold Tpm threshold for plotting tagcluster IQwidth
#' @param num_core Number of cores to run on
#' @return ce clustered CAGEexp object
#' @examples
#' cager_clustering(
#' ce,
#' iqw_plot_lim = c(0, 150),
#' sample_num_thr = 1,
#' ctss_thr = 1,
#' distclu_maxDist = 20,
#' keepSingletonsAbove = 5,
#' iqw_tpm_threshold = 3,
#' num_core = 4)

cager_clustering <- function(
        ce,
        iqw_plot_lim,
        sample_num_thr,
        ctss_thr,
        distclu_maxDist,
        keepSingletonsAbove,
        iqw_tpm_threshold,
        num_core,
        iqlow,
        iqhigh){

    multicore <- TRUE
    if(num_core < 2){
        multicore <- FALSE
        num_core <- NULL
    }

    # CTSS flagging used for filtering
    ce <- CAGEr::filterLowExpCTSS(
        ce,
        thresholdIsTpm = TRUE,
        nrPassThreshold = sample_num_thr,
        threshold = ctss_thr)

    # cluster TSS with distclu
    # filtered CTSS are excluded by default
    ce <- CAGEr::distclu(
        ce,
        maxDist=distclu_maxDist,
        keepSingletonsAbove = keepSingletonsAbove)

    # calculate IQ range
    ce <- CAGEr::cumulativeCTSSdistribution(
        ce,
        clusters = "tagClusters",
        useMulticore = multicore,
        nrCores = num_core)

    ce <- CAGEr::quantilePositions(
        ce,
        clusters = "tagClusters",
        qLow = iqlow,
        qUp = iqhigh)

    # plot IQ width
    iqw_plot <- CAGEr::plotInterquantileWidth(
        ce,
        clusters = "tagClusters",
        tpmThreshold = iqw_tpm_threshold,
        qLow = iqlow,
        qUp = iqhigh,
        xlim = iqw_plot_lim) # plot_lim
    save_plot(
        "interquartile_width_tagclusters_plot.pdf",
        iqw_plot)

    # count tag clusters
    sample_tag_cluster_count <- list()
    for (sample in CAGEr::sampleLabels(ce)) {
        sample_tag_cluster_count[[sample]] <- length(
            as.vector(score(CAGEr::tagClustersGR(ce, sample=sample))))
    }

    sink("plots/sample_tag_cluster_count.txt")
    print(sample_tag_cluster_count)
    sink()

    tag_clusters_count_plot <- plot_number_of_tag_clusters(
        sample_tag_count=sample_tag_cluster_count,
        yaxistitle="Number of tag clusters",
        mytitle="Number of tag clusters per sample")
    save_plot(
        "tag_clusters_counts_plot.pdf",
        tag_clusters_count_plot)

    return(ce)
}
