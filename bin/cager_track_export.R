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

    # genome seqlengths, used as a fallback when filling in BigBed seqinfo
    gsi <- GenomeInfoDb::seqinfo(CAGEr::CTSStagCountGR(ce, "all")[[1]])

    mapply(function(x, y){
        export_bigbed(x, paste0("tracks/", y, "_tagClusters.bb"), gsi)
    }, bedTracks, CAGEr::sampleLabels(ce))
}

export_consensus_clusters <- function(ce){
    ccbedTracks <- CAGEr::exportToTrack(
        ce,
        what = "consensusClusters",
        colorByExpressionProfile = FALSE,
        oneTrack = TRUE)

    # Only the BigBed track is emitted (the consensus-cluster BED has been
    # retired). export_bigbed reduces to a BED6, so no thickStart/thickEnd
    # column needs to be set here.
    gsi <- GenomeInfoDb::seqinfo(CAGEr::CTSStagCountGR(ce, "all")[[1]])
    export_bigbed(ccbedTracks, "tracks/consensusClusters.bb", gsi)
}
