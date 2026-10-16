//
// Removing reads which do not start with G
//

process READ_REMOVAL {
    label 'process_medium'
    stageInMode 'copy'

    input:
    tuple val(meta), path(input_fastq)

    output:
    tuple val(meta), path("filtered_output.fastq*.gz")

    script:
    if (meta.single_end) {
        """
        remove_non_g_fastq_se.py -f ${input_fastq} -b 'G'
        """
    } else {
        """
        remove_non_g_fastq_pe.py -f ${input_fastq[0]} -r ${input_fastq[1]} -b 'G'
        """
    }
}
