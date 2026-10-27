#' Normalization
#'
#' @param ce annotated CAGEexp object
#' @param rangeMin range min within which the slope is calculated
#' @param rangeMax range max within which the slope is calculated
#' @param method method of normalizing tag counts
#' @param t_norm total number of tags
#' @param user_alpha alpha value provided by the user to overwrite calculated from fitting reverse cumulative
#' @return ce normalized CAGEexp object
#' @examples
#' cager_normalization(
#' ce,
#' rangeMin=10,
#' rangeMax=10000,
#' method="powerLaw",
#' t_norm=1*10^6,
#' user_alpha=-1.05)

cager_normalization <- function(
    ce,
    rangeMin,
    rangeMax,
    method,
    t_norm,
    user_alpha){

    if (method == "powerLaw"){
        revcum_plots <- CAGEr::plotReverseCumulatives(
            object = ce,
            values = "raw",
            fitInRange = c(rangeMin, rangeMax))

        save_plot(
            "reverse_cumulative_plot.pdf",
            revcum_plots)

        if (user_alpha == "null"){
            slope_to_calc = -revcum_plots@meta$reference.slope
        } else{
            slope_to_calc = user_alpha
        }
    } else if (method == "simpleTpm" | method == "none") {
        # these parameters ignored for these methods
        slope_to_calc = 0
        t_norm = 0
        rangeMin = 0
        rangeMax = 0
    } else {
        stop("Invalid normalization method. Choose either 'powerLaw', 'simpleTpm', or 'none'.")
    }

    ce <- CAGEr::normalizeTagCount(
        ce,
        method = method,
        fitInRange = c(rangeMin, rangeMax),
        alpha = slope_to_calc,
        T = t_norm)

    return(ce)
}
