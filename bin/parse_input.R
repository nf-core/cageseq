#
# Parse incoming data from channel
#

parse_input <- function(sample_info, data_type){
    cleaned_string <- gsub("\\[", "", sample_info[[1]])
    cleaned_string <- gsub("\\]", "", cleaned_string)
    elements <- strsplit(cleaned_string, ",")[[1]]

    # Make sure that new_name works for BAM too
    if (tolower(data_type) == "bam"){
        sample_matrix <- matrix(elements, ncol=4, byrow=TRUE)
        sample_table <- as.data.frame(
            sample_matrix, stringsAsFactors=FALSE)
        colnames(sample_table) <- c("id", "single_end", "path", "new_name")
    }else if (tolower(data_type) == "bigwig") {
        sample_matrix <- matrix(elements, ncol=5, byrow=TRUE)
        sample_table <- as.data.frame(
            sample_matrix, stringsAsFactors=FALSE)
        colnames(sample_table) <- c("id", "single_end", "path1", "path2", "new_name")
        sample_table$path <- paste(sample_table$path1, sample_table$path2, sep=",")
    } else {
        stop("Either bigwig or bam files should be provided")
    }

    return(sample_table)
}
