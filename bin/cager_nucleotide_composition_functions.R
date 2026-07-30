# Functions to calulcate and plot dinucleotide composition

# Given a GRanges of single-base TSS positions carrying a `score` column, extract
# the initiator dinucleotide (-1/+1 around the TSS) of each position, sum the
# scores per dinucleotide and turn them into within-sample proportions. Shared by
# both the dominant-TSS and all-TSS dinucleotide extractors below so their
# downstream handling is guaranteed to be identical.
dinuc_proportions_from_positions <- function(positions_gr, bsgenome) {
    tmp <- IRanges::promoters(
        positions_gr,
        upstream = 1,
        downstream = 1)
    tmp <- tmp[width(trim(tmp)) == 2]
    tmp$dinucleotide <- as.data.frame(getSeq(bsgenome, tmp))$x

    dinuc_n_score<-as.data.frame(tmp)[,c("score","dinucleotide")]
    dinucleotide_list <- unique(dinuc_n_score$dinucleotide)
    dinuc_vals <- data.frame(
        dinucleotide=dinucleotide_list,
        sum_score=NA)
    for (dn in dinucleotide_list) {
        dinuc_vals[which(dinuc_vals$dinucleotide==dn),]$sum_score <- sum(
            dinuc_n_score[which(dinuc_n_score$dinucleotide==dn),]$score)
    }

    dinuc_vals$proportion <- dinuc_vals$sum_score/sum(dinuc_vals$sum_score)

    dinuc_vals<-dinuc_vals[
        order(dinuc_vals$proportion, decreasing=F),]
    dinuc_vals$dinucleotide <- factor(
        dinuc_vals$dinucleotide,
        levels = dinuc_vals$dinucleotide)

    return(dinuc_vals)
}

extract_dinucleotide_information <- function(ce, reference_name, qLow = 0.1, qUp = 0.9) {
    bsgenome <- BSgenome::getBSgenome(reference_name)
    sample_names <- CAGEr::sampleLabels(ce)
    weigthed_dinuc_vals <- list()
    for (sample in sample_names) {
        tmp <- as.data.frame(CAGEr::tagClustersGR(
            ce,
            sample = sample,
            qLow = qLow, qUp = qUp))
        tmp <- GenomicRanges::GRanges(
            seqnames = tmp$seqnames,
            ranges =  IRanges::IRanges(
                start = tmp$dominant_ctss.pos,
                end = tmp$dominant_ctss.pos),
            strand = tmp$strand,
            score=tmp$dominant_ctss.score,
            seqlengths = seqlengths(bsgenome))

        weigthed_dinuc_vals[[sample]] <- dinuc_proportions_from_positions(
            tmp, bsgenome)
    }
    weigthed_dinuc_vals_df <- dplyr::bind_rows(weigthed_dinuc_vals, .id="samples")
    return(weigthed_dinuc_vals_df)
}

# All-TSS counterpart of extract_dinucleotide_information. Instead of the single
# dominant TSS per tag cluster, it uses every CTSS that is expressed at tpm >=
# ctss_thr in at least sample_num_thr samples (the same low-expression filter
# applied before tag clustering), weighting each by its per-sample normalized
# tpm. This reveals the initiator dinucleotide preference across the whole set of
# high-fidelity TSSs rather than only the dominant ones.
extract_dinucleotide_information_all_ctss <- function(
    ce, reference_name, ctss_thr, sample_num_thr) {

    bsgenome <- BSgenome::getBSgenome(reference_name)
    sample_names <- CAGEr::sampleLabels(ce)

    ctss_gr <- CAGEr::CTSScoordinatesGR(ce)
    tpm_df <- as.data.frame(CAGEr::CTSSnormalizedTpmDF(ce))

    # Keep the CTSSs expressed at >= ctss_thr tpm in at least sample_num_thr
    # samples. This mirrors CAGEr::filterLowExpCTSS(thresholdIsTpm = TRUE,
    # nrPassThreshold = sample_num_thr, threshold = ctss_thr) used before tag
    # clustering, so the plot is based on exactly that high-fidelity CTSS set.
    pass_counts <- rowSums(tpm_df >= ctss_thr)
    keep <- pass_counts >= sample_num_thr
    ctss_gr <- ctss_gr[keep]
    tpm_df <- tpm_df[keep, , drop = FALSE]

    weigthed_dinuc_vals <- list()
    for (sample in sample_names) {
        scores <- as.numeric(tpm_df[[sample]])
        # Only positions actually expressed in this sample contribute to its
        # dinucleotide proportions.
        expressed <- scores > 0
        sample_gr <- ctss_gr[expressed]
        GenomicRanges::mcols(sample_gr)$score <- scores[expressed]

        weigthed_dinuc_vals[[sample]] <- dinuc_proportions_from_positions(
            sample_gr, bsgenome)
    }
    weigthed_dinuc_vals_df <- dplyr::bind_rows(weigthed_dinuc_vals, .id="samples")
    return(weigthed_dinuc_vals_df)
}

plot_dinucleotide_frequency_heatmap <- function(
        weigthed_dinuc_vals_df,
        title = NULL) {

    # Order dinucleotides by the median (across samples) of their proportions.
    # The x axis is not flipped here, so the first factor level sits at the
    # left; descending order renders the largest median on the left.
    dinuc_order <- stats::aggregate(
        proportion ~ dinucleotide,
        data = weigthed_dinuc_vals_df,
        FUN = median)
    dinuc_order <- dinuc_order[
        order(dinuc_order$proportion, decreasing = TRUE), ]
    weigthed_dinuc_vals_df$dinucleotide <- factor(
        weigthed_dinuc_vals_df$dinucleotide,
        levels = dinuc_order$dinucleotide)

    # Order samples by the natural ordering of their names on the y axis. The
    # first factor level is drawn at the bottom, so reversing puts the first
    # sample at the top.
    weigthed_dinuc_vals_df$samples <- factor(
        weigthed_dinuc_vals_df$samples,
        levels = rev(natural_sort(unique(weigthed_dinuc_vals_df$samples))))

    p <- ggplot(
        data = weigthed_dinuc_vals_df,
        aes(x = dinucleotide, y = samples, fill = proportion)) +
        geom_tile() +
        xlab("Initiator dinucleotide") +
        ylab("Samples") +
        ggtitle(title) +
        theme_bw() +
        theme(
            text = element_text(size = 40, colour = "black"),
            axis.text.x = element_text(size = 30, colour = "black",angle = 90),
            axis.text.y = element_text(size = 30, colour = "black"),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank()) +
        labs(fill = "%")
    return(p)
}

plot_dinucleotide_frequency_histogram <- function(
    weigthed_dinuc_vals_df,
    col,
    title = "Dominant TSS dinucleotide (-/+ 1bp) proportion weighted by the sum of dominant TSS score per sample") {

    # Order dinucleotides by the median (across samples) of their proportions.
    # coord_flip() puts the first factor level at the bottom, so
    # ascending order renders the largest median at the top of the y axis.
    dinuc_order <- stats::aggregate(
        proportion ~ dinucleotide,
        data = weigthed_dinuc_vals_df,
        FUN = median)
    dinuc_order <- dinuc_order[
        order(dinuc_order$proportion, decreasing = FALSE), ]
    weigthed_dinuc_vals_df$dinucleotide <- factor(
        weigthed_dinuc_vals_df$dinucleotide,
        levels = dinuc_order$dinucleotide)

    # Order samples by the natural ordering of their names. With coord_flip()
    # the dodged bars read top-to-bottom in the reverse of the factor levels,
    # so reversing puts the first sample at the top. The legend is reversed
    # below so that it lists the samples in the same order as the bars.
    weigthed_dinuc_vals_df$samples <- factor(
        weigthed_dinuc_vals_df$samples,
        levels = rev(natural_sort(unique(weigthed_dinuc_vals_df$samples))))

    p <- ggplot(
        data = weigthed_dinuc_vals_df,
        aes(x = dinucleotide, y = proportion, fill = samples)) +
        scale_fill_manual(values = col) +
        guides(fill = guide_legend(reverse = TRUE)) +
        geom_bar(
            stat = "identity",
            position = position_dodge(),
            colour = "black",
            size = 0.3,
            linewidth = 0.25) +
        coord_flip() +
        xlab("Initiator dinucleotide") +
        ylab("Proportion of total per sample") +
        ggtitle(title) +
        theme_bw() +
        theme(
            text = element_text(size = 60, colour = "black"),
            axis.text.x = element_text(size = 60, colour = "black"),
            axis.text.y = element_text(size = 60, colour = "black"),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            legend.text = element_text(size = 10)) +
        scale_y_continuous(limits = c(0, 1)) +
        labs(fill = NULL)

    return(p)
}

plot_dinucleotide_frequency <- function(
        weigthed_dinuc_vals_df,
        title = "Dominant TSS dinucleotide (-/+ 1bp) proportion weighted by the sum of dominant TSS score per sample") {

    column_names <- natural_sort(unique(weigthed_dinuc_vals_df$samples))
    col = viridis::magma(
        length(column_names),
        alpha = 0.8)[length(column_names):1]
    # Name the colours by sample so that scale_fill_manual maps each sample to
    # the same colour regardless of how the sample factor levels are ordered.
    names(col) <- column_names

    # heatmap if more than 10 samples, otherwise barplot
    if (length(column_names) > 10){
        p <- plot_dinucleotide_frequency_heatmap(
            weigthed_dinuc_vals_df=weigthed_dinuc_vals_df,
            title=title
        )
    } else {
        p <- plot_dinucleotide_frequency_histogram(
            weigthed_dinuc_vals_df=weigthed_dinuc_vals_df,
            col=col,
            title=title)
    }
    return(p)
}
