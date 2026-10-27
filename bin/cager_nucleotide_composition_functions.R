# Functions to calulcate and plot dinucleotide composition

extract_dinucleotide_information <- function(ce, reference_name) {
    bsgenome <- BSgenome::getBSgenome(reference_name)
    sample_names <- CAGEr::sampleLabels(ce)
    weigthed_dinuc_vals <- list()
    for (sample in sample_names) {
        tmp <- as.data.frame(CAGEr::tagClustersGR(
            ce,
            sample = sample,
            qLow = 0.1,qUp = 0.9))
        tmp <- GenomicRanges::GRanges(
            seqnames = tmp$seqnames,
            ranges =  IRanges::IRanges(
                start = tmp$dominant_ctss.pos,
                end = tmp$dominant_ctss.pos),
            strand = tmp$strand,
            score=tmp$dominant_ctss.score,
            seqlengths = seqlengths(bsgenome))
        tmp <- IRanges::promoters(
            tmp,
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

        weigthed_dinuc_vals[[sample]] <- dinuc_vals
    }
    weigthed_dinuc_vals_df <- dplyr::bind_rows(weigthed_dinuc_vals, .id="samples")
    return(weigthed_dinuc_vals_df)
}

plot_dinucleotide_frequency_heatmap <- function(
        weigthed_dinuc_vals_df) {

    p <- ggplot(
        data = weigthed_dinuc_vals_df,
        aes(x = dinucleotide, y = samples, fill = proportion)) +
        geom_tile() +
        xlab("Initiator dinucleotide") +
        ylab("Samples") +
        ggtitle(NULL) +
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
    weigthed_dinuc_vals_df, col) {

    p <- ggplot(
        data = weigthed_dinuc_vals_df,
        aes(x = dinucleotide, y = proportion, fill = samples)) +
        scale_fill_manual(values = col) +
        geom_bar(
            stat = "identity",
            position = position_dodge(),
            colour = "black",
            size = 0.3,
            linewidth = 0.25) +
        coord_flip() +
        xlab("Initiator dinucleotide") +
        ylab("Proportion of total per sample") +
        ggtitle("Dominant TSS dinucleotide (-/+ 1bp) proportion weighted by the sum of dominant TSS score per sample") +
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
        weigthed_dinuc_vals_df) {

    column_names <- sort(unique(weigthed_dinuc_vals_df$samples))
    col = viridis::magma(
        length(column_names),
        alpha = 0.8)[length(column_names):1]

    # heatmap if more than 10 samples, otherwise barplot
    if (length(column_names) > 10){
        p <- plot_dinucleotide_frequency_heatmap(
            weigthed_dinuc_vals_df=weigthed_dinuc_vals_df
        )
    } else {
        p <- plot_dinucleotide_frequency_histogram(
            weigthed_dinuc_vals_df=weigthed_dinuc_vals_df,
            col=col)
    }
    return(p)
}
