save_plot <- function(filename, plot_out){
    filename = paste0("plots/", filename)
    ggsave(
        filename = filename,
        plot = plot_out,
        width = 20,
        height = 10,
        limitsize = FALSE)
    datafilename <- gsub("pdf", "rds", filename)
    saveRDS(plot_out, datafilename)
}

make_no_enhancer_plot = function() {
    rect.text.p = ggplot(
        data.frame(
            x1 = 0,
            x2 = 4,
            y1 = 0,
            y2 = 4)) +
        geom_rect(
            aes(
                xmin = x1,
                xmax = x2,
                ymin = y1,
                ymax = y2),
            colour = "black",
            fill = "white") +
        geom_text(
            x = 2,
            y = 2,
            label = "No enhancers found",
            colour = "black",
            size = 6) +
        theme_void()
    return(rect.text.p)
}
