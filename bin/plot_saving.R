save_plot <- function(filename, plot_out, height = 10){
    filename = paste0("plots/", filename)
    ggsave(
        filename = filename,
        plot = plot_out,
        width = 20,
        height = height,
        limitsize = FALSE)
    datafilename <- gsub("pdf", "rds", filename)
    saveRDS(plot_out, datafilename)
}

# Create a simple placeholder plot displaying a single (word-wrapped) message on
# a white, bordered rectangle. Used whenever a real plot cannot be produced
# (an error occurred, or there was nothing to plot) so that the CAGEr report can
# still be rendered in the place where the real plot would normally go. Base R
# strwrap is used for wrapping so no extra package is required in either of the
# scripts that source this file.
make_message_plot = function(message) {
    wrapped <- paste(strwrap(message, width = 30), collapse = "\n")
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
            label = wrapped,
            colour = "black",
            size = 6) +
        coord_cartesian(clip = "off") +
        theme_void()
    return(rect.text.p)
}

# Kept for backwards compatibility; the message wording now matches the
# "No enhancers called" placeholder used in the enhancer report section.
make_no_enhancer_plot = function() {
    make_message_plot("No enhancers called")
}

# Write the message of a captured error to a text file in the plots/ folder so
# that it is published alongside the placeholder plot in the results directory.
save_error_log <- function(filename, e) {
    writeLines(conditionMessage(e), file.path("plots", filename))
}
