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

    # BED9 text track (chrom, start, end, name, score, strand, thickStart,
    # thickEnd, itemRgb). A consensus cluster aggregates per-sample tag
    # clusters whose dominant TSS may differ, so no dominant TSS or
    # interquantile block structure is drawn: each cluster is a plain
    # stranded feature. Without a block structure, genome browsers draw the
    # strand chevrons inside the feature itself, which a single-block BED12
    # feature does not get. In addition the strand is made evident in two more
    # ways: the name is CAGEr's cluster id, which ends in the strand
    # (e.g. chrIII:17250-17274:+), and the feature is coloured by strand
    # (plus = red, minus = blue; UCSC needs itemRgb="On" on the track line to
    # use the colours, IGV uses them as they are).
    ccbedTracks <- methods::as(ccbedTracks, "GRanges")
    ccbedTracks$blocks <- NULL
    ccbedTracks$name <- names(CAGEr::consensusClustersGR(ce))
    ccbedTracks$thick <- IRanges::ranges(ccbedTracks)
    ccbedTracks$itemRgb <- ifelse(
        as.character(GenomicRanges::strand(ccbedTracks)) == "-",
        "#0000FF", "#FF0000")
    rtracklayer::export.bed(ccbedTracks, "tracks/consensusClusters.bed")
}
