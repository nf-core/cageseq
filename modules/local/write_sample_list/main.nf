//
// Write sample list to file
//

process WRITE_SAMPLE_LIST {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(bw_or_bam)
    val outdir

    output:
    path "sample_list.csv", emit: sample_list

    when:
    task.ext.when == null || task.ext.when

    script:
    if ( bw_or_bam[1] != null )
        """
        echo "${meta.id},${meta.single_end},[${outdir}/bigwig/${bw_or_bam[0]} ${outdir}/bigwig/${bw_or_bam[1]}],${meta.id}" > sample_list.csv
        """
    else
        """
        echo "${meta.id},${meta.single_end},${outdir}/samtools_sort/${bw_or_bam[0]},${meta.id}" > sample_list.csv
        """

    stub:
    """
    touch sample_list.csv
    """
}
