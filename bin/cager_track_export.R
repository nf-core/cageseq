bigwig_export <- function(x, y, type){
    tracks <- split(x, strand(x))
    rtracklayer::export.bw(tracks$`+`, paste0("tracks/", paste(y, type, "plus.bw", sep="_")))
    min <- tracks$`-`
    min$score <- min$score * (-1)
    rtracklayer::export.bw(min, paste0("tracks/", paste(y, type, "minus.bw", sep="_") ))
}

export_tagclusters <- function(ce, iqlow, iqhigh){
    # export normalized TSS counts into bigwig
    mapply(
        bigwig_export,
        CAGEr::CTSSnormalizedTpmGR(ce, "all"),
        CAGEr::sampleLabels(ce),
        "normalized")

    # export raw TSS counts into bigwig
    mapply(
        bigwig_export,
        CAGEr::CTSStagCountGR(ce, "all"),
        CAGEr::sampleLabels(ce),
        "raw")

    bedTracks <- CAGEr::exportToTrack(
        ce,
        what = "tagClusters",
        qLow = iqlow, qUp = iqhigh,
        oneTrack = FALSE)

    mapply(function(x, y){
        rtracklayer::export.bed(x, paste0("tracks/", y, "_tagClusters.bed"))
    }, bedTracks, CAGEr::sampleLabels(ce))
}

export_consensus_clusters <- function(ce){
    ccbedTracks <- CAGEr::exportToTrack(
        ce,
        what = "consensusClusters",
        colorByExpressionProfile = FALSE,
        oneTrack = TRUE)
    # should start at 1 for export to be 0
    thick_start <- rep(1, length(ccbedTracks))
    thick_end <- thick_start
    thick_width <- thick_start
    ccbedTracks$thick <- IRanges(
        start=thick_start, end=thick_end, width=thick_width)
    rtracklayer::export.bed( ccbedTracks, "tracks/consensusClusters_prefix.bed")
}
