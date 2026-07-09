//
// Write sample list to file
//

process WRITE_SAMPLE_LIST {

    input:
    tuple val(meta), path(bw_or_bam)

    output:
    path("sample_list.csv")

    script:
    if ( bw_or_bam[1] != null )
        """
        line="${meta.id},${meta.single_end},${PWD}/${params.outdir}/bigwig/${bw_or_bam[0]},${PWD}/${params.outdir}/bigwig/${bw_or_bam[1]},${meta.id}"
        echo \$line > sample_list.csv
        """
    else
        """
        line="${meta.id},${meta.single_end},${PWD}/${params.outdir}/samtools_sort/${bw_or_bam[0]},${meta.id}"
        echo \$line > sample_list.csv
        """
}
