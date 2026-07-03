#' Export a CAGEr/CAGEfightR track GRanges to BigBed format
#'
#' Sole on-disk track writer for the tag cluster, consensus cluster and enhancer
#' tracks (the plain-BED outputs have been retired). BigBed is stricter than
#' plain BED: it needs complete seqlengths, features sorted by coordinate,
#' non-NA character names and an integer score in [0, 1000]. This helper
#' normalises a track GRanges so those constraints are met and writes the .bb
#' file. The unscaled scores and full per-cluster attributes remain available in
#' the CAGEr/CAGEfightR objects and the exported tables and bigWig tracks.
#'
#' @param gr A GRanges (or UCSCData) track, e.g. from CAGEr::exportToTrack or
#'   CAGEfightR. May carry name/score/thick/blocks/itemRgb metadata columns.
#' @param con Output path for the BigBed file.
#' @param seqlengths_src Optional object carrying genome seqlengths (a Seqinfo,
#'   GRanges, BSgenome, ...) used to fill in any seqlengths missing on `gr`.
#' @return Invisibly, `con`.
#' @export
export_bigbed <- function(gr, con, seqlengths_src = NULL) {
    # Drop any UCSCData track line; BigBed files do not carry one.
    gr <- methods::as(gr, "GRanges")

    # A BigBed file cannot be built from zero features; skip quietly so this
    # mirrors export.bed's tolerance and never becomes a crash vector.
    if (length(gr) == 0) {
        warning("export_bigbed: no features to write for '", con, "'; skipping.")
        return(invisible(con))
    }

    # BigBed needs complete seqlengths; fill them from the genome if missing.
    if (any(is.na(GenomeInfoDb::seqlengths(gr))) && !is.null(seqlengths_src)) {
        sl <- GenomeInfoDb::seqlengths(seqlengths_src)
        common <- intersect(GenomeInfoDb::seqlevels(gr), names(sl))
        GenomeInfoDb::seqlengths(gr)[common] <- sl[common]
    }

    # BigBed rejects features that run past the chromosome end (e.g. an enhancer
    # or cluster window extended beyond the last base -> "End coordinate ... bigger
    # than <chrom> size ..."). Trim any out-of-bound ranges back to their sequence
    # bounds; trim() only touches seqlevels whose length is known, leaving the rest
    # untouched.
    gr <- GenomicRanges::trim(gr)

    # Keep only the seqlevels actually used, then sort by genome and coordinate.
    gr <- GenomeInfoDb::keepSeqlevels(
        gr, unique(as.character(GenomicRanges::seqnames(gr))),
        pruning.mode = "coarse")
    gr <- sort(GenomeInfoDb::sortSeqlevels(gr))

    # BigBed requires non-NA character names; fall back to coordinates.
    coords <- paste0(GenomicRanges::seqnames(gr), ":",
                     GenomicRanges::start(gr), "-", GenomicRanges::end(gr))
    nm <- if (is.null(gr$name)) coords else as.character(gr$name)
    blank <- is.na(nm) | nm %in% c(".", "")
    nm[blank] <- coords[blank]
    gr$name <- nm

    # BigBed score must be an integer in [0, 1000]. CAGE (TPM) scores routinely
    # exceed this, so scale them onto the range for browser shading; the exact
    # values are preserved in the BED and bigWig tracks.
    sc <- GenomicRanges::score(gr)
    if (is.null(sc)) sc <- rep(0, length(gr))
    sc[is.na(sc)] <- 0
    mx <- suppressWarnings(max(sc))
    gr$score <- if (is.finite(mx) && mx > 0) {
        as.integer(round(pmin(pmax(sc, 0) / mx * 1000, 1000)))
    } else {
        0L
    }

    # rtracklayer's BigBed writer serialises every metadata column it does not
    # recognise as a standard leading BED field into an autoSql "extra field".
    # CAGEr tracks carry several such columns (quantile positions `q_0.1`/`q_0.9`,
    # `nr_ctss`, `dominant_ctss`, `interquantile_width`, ...) and, in the
    # container's rtracklayer (>= 1.69), `thick` and `blocks` are NOT mapped to
    # the BED12 thickStart/thickEnd/block fields either. Any of these become
    # extra fields whose type the UCSC autoSql writer cannot encode, e.g. an Rle
    # `q_0.1` or an IRanges `thick` -> "Unknown type 'NA'" and the dot in the
    # name -> "Expecting ; got .", aborting with "UCSC library operation failed".
    # BED12 BigBed is not portable across the rtracklayer versions in play here
    # (host 1.54 tolerates thick/blocks, the container's 1.69 does not) and
    # bedToBigBed is unavailable, so emit a robust BED6 instead: chrom/start/end
    # and strand come from the GRanges core, plus name and score. The richer
    # per-cluster attributes (thickStart/thickEnd, interquantile blocks, quantile
    # positions) remain in the CAGEr/CAGEfightR objects and the exported tables.
    keep <- intersect(c("name", "score"), names(S4Vectors::mcols(gr)))
    S4Vectors::mcols(gr) <- S4Vectors::mcols(gr)[, keep, drop = FALSE]

    rtracklayer::export.bb(gr, con)
    invisible(con)
}
