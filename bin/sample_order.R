# Sample ordering helpers shared by the CAGEr scripts.

# Natural (numeric-aware) ordering of sample names, e.g. S1, S2, ..., S9, S10,
# S11 rather than the lexicographic S1, S10, S11, S2, ... Implemented in base R
# (no extra dependency) by zero-padding every run of digits to a common width
# so that ordinary lexicographic ordering of the padded key is the natural one.
natural_sort <- function(x) {
    x <- as.character(x)
    digit_runs <- regmatches(x, gregexpr("[0-9]+", x))
    all_digits <- unlist(digit_runs)
    pad_width <- if (length(all_digits)) max(nchar(all_digits)) else 0L
    key <- x
    regmatches(key, gregexpr("[0-9]+", key)) <- lapply(
        digit_runs,
        function(d) formatC(as.integer(d), width = pad_width, flag = "0"))
    x[order(key)]
}

# Order in which samples are shown in the plots that do not cluster samples:
# the given order (the user's sample sheet / sample list order, as kept in the
# CAGEexp object) unless sort_samples is TRUE, in which case the natural order.
order_samples <- function(x, sort_samples = FALSE) {
    x <- as.character(x)
    if (isTRUE(sort_samples)) natural_sort(x) else x
}
