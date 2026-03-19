process GTF2TXDB {
    label 'process_medium'
    stageInMode 'copy'

    input:
    path gtf

    output:
    path "*.sqlite",     emit: txdb
    path "versions.yml", emit: versions, topic: versions

    """
    gtf_to_txdb.R -g ${gtf}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_txdbmaker: \$(Rscript -e 'packageVersion("txdbmaker")' | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """
}
