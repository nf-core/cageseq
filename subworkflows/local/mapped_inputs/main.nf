//
// Create channel from mapping file content
//

workflow MAPPED_INPUTS {
    take:
    sample_file

    main:
    input_files = sample_file
        .splitCsv( header:true , sep:',')
        .map { row -> create_sample_channel(row) }

    emit:
    input_files = input_files
}

def create_sample_channel(LinkedHashMap row) {
    def files_in = row.path
    def files = files_in.split(' ')
    if (files.size() == 2){
        def bigwig_1 = file(files[0].minus('['))
        def bigwig_2 = file(files[1].minus(']'))
        return [bigwig_1, bigwig_2]
    } else if (files.size() == 1){
        def bam = file(files[0].minus('[').minus(']'))
        return [bam]
    } else {
        throw new IllegalArgumentException(
            "Only 1 (bam) or 2 (bigwig) files are supported")
    }
}
