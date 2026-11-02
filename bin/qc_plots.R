####################
## Plot functions ##
####################

required.libraries <- c(
    "ggplot2",
    "viridis",
    "tidyverse"
)

for (lib in required.libraries) {
    suppressPackageStartupMessages(library(lib, character.only=TRUE, quietly = T))
}

# natural_sort() and order_samples() (sample order in the plots) live in
# bin/sample_order.R; project_dir is set by every script before sourcing this file.
source(file.path(project_dir, "bin/sample_order.R"))

plot_settings <- function(.data, y_value, color_by_value, y_label, title, y_value_max) {
    .data %>% ggplot(aes(
        x = .data[["Sample"]],
        y = .data[[y_value]],
        colour = .data[[color_by_value]])) +
    geom_point(size = 5) +
    scale_color_viridis(
        discrete = TRUE,
        begin = 0.1,
        end = 0.9,
        option = "magma") +
    theme_bw(base_size = 12) +
    ylab(y_label) +
    xlab("") +
    ylim(0, y_value_max+1000) +
    ggtitle(title) +
    theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position="none")
}

plot_number_of_tag_clusters <- function(
    sample_tag_count,
    yaxistitle,
    mytitle,
    myfilename,
    sort_samples = FALSE) {
    sample_tag_count_table <- tibble::enframe(
        sample_tag_count,
        name = "Sample",
        value = "count") %>%
        tidyr::unnest(cols=count)
    # Order the samples on the x axis (user's order, or natural order when
    # sort_samples is TRUE) and always put the "Union" summary column last.
    sample_levels <- order_samples(unique(sample_tag_count_table$Sample), sort_samples)
    sample_levels <- c(
        setdiff(sample_levels, "Union"),
        intersect(sample_levels, "Union"))
    sample_tag_count_table$Sample <- factor(
        sample_tag_count_table$Sample,
        levels = sample_levels)
    tag_count_plot <- sample_tag_count_table %>%
        plot_settings(
            y_value = "count",
            color_by_value = "Sample",
            y_label = yaxistitle,
            title = mytitle,
            y_value_max=max(sample_tag_count_table$count))
    return(tag_count_plot)
}

plot_correlation <- function(
    datatype,
    dataframe,
    corrplot_tagCountThreshold){

    corr_m <- CAGEr::correlationMatrix(
        dataframe,
        samples = "all",
        tagCountThreshold = corrplot_tagCountThreshold,
        applyThresholdBoth = FALSE,
        method = "pearson")

    sample_size <- dim(corr_m)[1]
    heatmap_cex <- sample_size^(-0.2)

    # plot correlations in heatmap format
    # The colour scheme is the exact reverse of gplots' default "heat.colors" so
    # that the higher the correlation the more red the cell is (low correlations
    # are creamy/pale). Passing a *function* (rather than a fixed colour vector)
    # is important: heatmap.2 then keeps its default granularity (breaks = 16 ->
    # 15 colours) and the cyan colour-key histogram, only reversing the gradient
    # order (creamy at the minimum, red at the maximum). A fixed-length vector
    # would instead force one break per colour, breaking the key into hundreds of
    # cells and collapsing the histogram. Only base (grDevices) functions are
    # used so that eval(hm$call) can redraw it in the report, where gplots is not
    # attached.
    hm <- gplots::heatmap.2(
        corr_m,
        trace="none",
        col=function(n) rev(grDevices::heat.colors(n)),
        margins=c(12, 12),
        cexRow=heatmap_cex,
        cexCol=heatmap_cex)

    file_prefix = paste0("plots/", datatype, "_correlations")
    pdf(paste0(file_prefix, "_plot.pdf"))
    eval(hm$call)
    dev.off()
    saveRDS(hm, paste0(file_prefix, "_plot.rds"))

    # save intermediate file
    saveRDS(corr_m, paste0(file_prefix, "_matrix.rds"))
}

plot_pcs <- function(count_matrix){
    # find top 500 most variable genes
    vars <- apply(count_matrix, 1, var)
    top_features <- min(length(vars), 500)
    top_var_idx <- order(vars, decreasing = T)[1:top_features]
    top_var <- count_matrix[top_var_idx, ]

    # run PCA
    pca_out <- top_var %>% as.data.frame %>%
        dplyr::mutate(across(everything(), ~ log10(.x + .1))) %>%
        t() %>%
        prcomp
    # get information about PCA
    eigs <- pca_out$sdev^2
    vars_explained <- eigs / sum(eigs)

    # plot PCA
    pca_plot <- as.data.frame(pca_out$x) %>%
        rownames_to_column(var = "sample") %>%
        ggplot(aes(PC1, PC2, label=sample)) +
        geom_point(size = 3) +
    ggrepel::geom_text_repel(
        hjust=0,
        vjust=0,
        size=2,
        max.overlaps=5) +
    theme_bw() +
    scale_color_brewer(palette = "Set1") +
    xlab(sprintf("PC1 (%.2f%%)", vars_explained[1] *100)) +
    ylab(sprintf("PC2 (%.2f%%)", vars_explained[2] *100))

    return(pca_plot)
}
