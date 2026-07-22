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
        # BED12 text track. The full per-cluster attributes are preserved: the
        # dominant TSS as thickStart/thickEnd (a "coding exon") and the
        # interquantile range (qLow..qUp) as the block structure.
        # Coerce away the UCSCData wrapper so no "track ..." line is written.
        rtracklayer::export.bed(
            methods::as(x, "GRanges"),
            paste0("tracks/", y, "_tagClusters.bed"))
    }, bedTracks, CAGEr::sampleLabels(ce))
}

export_consensus_clusters <- function(ce){
    ccbedTracks <- CAGEr::exportToTrack(
        ce,
        what = "consensusClusters",
        colorByExpressionProfile = FALSE,
        oneTrack = TRUE)

    # BED12 text track. A consensus cluster aggregates per-sample tag clusters
    # whose dominant TSS may differ, so no single dominant TSS is represented:
    # the whole cluster span is written as one block and the thick region is
    # collapsed to zero width at the cluster start (thickStart == thickEnd), so
    # browsers draw a single thin block with no coding-exon marker.
    ccbedTracks <- methods::as(ccbedTracks, "GRanges")
    ccbedTracks$blocks <- IRanges::IRangesList(lapply(
        GenomicRanges::width(ccbedTracks),
        function(w) IRanges::IRanges(start = 1, width = w)))
    ccbedTracks$thick <- IRanges::IRanges(
        start = GenomicRanges::start(ccbedTracks), width = 0)
    rtracklayer::export.bed(ccbedTracks, "tracks/consensusClusters.bed")
}
