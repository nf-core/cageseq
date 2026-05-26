//
// Create channel from folder
//

workflow INPUT_FROM_FOLDER {

    take:
    infolder

    main:
    any_R2_file = file("$infolder/**_R2*fastq.gz")
    singleEnd = true
    if (any_R2_file.size() > 0){
        singleEnd = false
    }
    if (singleEnd){
        any_2_file = file("$infolder/**_2*fastq.gz")
        if (any_2_file.size() > 0){
            singleEnd = false
        }
    }

    ch_fastq = channel
        .fromFilePairs(
            ["$infolder/**_R{1,2}*fastq.gz", "$infolder/**_{1,2}*fastq.gz"],
            size: singleEnd ? 1 : 2)
        .map{
            old_meta, fastq ->
                def meta = [:]
                def num_fields_of_interest = "$params.sample_name_fields".toInteger()
                def split_field_num = old_meta.split('_').size()
                def sample_name = ""
                def lane_n_fastq = []
                if (split_field_num == 1 ){
                    sample_name = old_meta
                    lane_n_fastq = tuple(fastq.name, fastq)
                } else {
                    def num_fields_to_cut = split_field_num - num_fields_of_interest
                    num_fields_to_cut = num_fields_to_cut == 0 ? 2 : num_fields_to_cut + 1
                    sample_name = old_meta.split('_')[0..-num_fields_to_cut].join('_')
                    lane_n_fastq = tuple((fastq.name =~ /L00\d/)[0], fastq)
                }
                meta.id = sample_name.replaceAll('-','_')
                meta.single_end = singleEnd
                [meta, lane_n_fastq] }
        .groupTuple()
        .map{
            meta, lane_n_fastq ->
                meta = meta
                def fastq = lane_n_fastq*.getAt(1).flatten()
                [meta, fastq] }

    emit:
    ch_fastq = ch_fastq
}
