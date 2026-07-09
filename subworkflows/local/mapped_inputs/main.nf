//
// Create channel from mapping file content
//

workflow MAPPED_INPUTS {
    take:
    sample_file

    main:
    input_files = sample_file
        .splitCsv( header:true , sep:',')
        .map { create_sample_channel(it) }

    emit:
    input_files
}

def create_sample_channel(LinkedHashMap row) {
    // New format: bigWigs live in separate path1/path2 columns.
    if (row.containsKey('path2')) {
        return [file(row.path1), file(row.path2)]
    }
    // Single "path" column. Accept both the new plain form and the legacy
    // "[str1 str2]" bracketed/space-separated form for backwards compatibility
    // with pre-existing sample lists.
    def files = row.path.replaceAll(/[\[\]]/, '').split(/[ ,]+/)
    if (files.size() == 2){
        return [file(files[0]), file(files[1])]
    } else if (files.size() == 1){
        return [file(files[0])]
    } else {
        throw new IllegalArgumentException(
            "Only 1 (bam) or 2 (bigwig) files are supported")
    }
}
