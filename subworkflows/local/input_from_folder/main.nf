//
// Create channel from folder
//

include { fixSampleName } from '../sample_names/main.nf'

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
                num_fields_of_interest = "$params.sample_name_fields".toInteger()
                split_field_num = old_meta.split('_').size()
                if (split_field_num == 1 ){
                    sample_name = old_meta
                    lane_n_fastq = tuple(fastq.name, fastq)
                } else {
                    num_fields_to_cut = split_field_num - num_fields_of_interest
                    num_fields_to_cut = num_fields_to_cut == 0 ? 2 : num_fields_to_cut + 1
                    sample_name = old_meta.split('_')[0..-num_fields_to_cut].join('_')
                    lane_n_fastq = tuple((fastq.name =~ /L00\d/)[0], fastq)
                }
                // Names derived from file names are corrected rather than rejected:
                // hyphens -> underscores, 'Sample' prefix for a leading digit.
                def (fixed_name, changes) = fixSampleName(sample_name)
                if (changes) {
                    log.warn "Sample name '${sample_name}', derived from the FASTQ file name(s) in --infolder, " +
                        "was changed to '${fixed_name}': ${changes.join('; ')}. " +
                        "Sample names must not contain hyphens and must not start with a digit."
                }
                meta.id = fixed_name
                meta.single_end = singleEnd
                [meta, lane_n_fastq] }
        .groupTuple()
        .map{
            meta, lane_n_fastq ->
                meta = meta
                fastq = lane_n_fastq*.getAt(1).flatten()
                [meta, fastq] }

    emit:
    ch_fastq
}
