process FORGE_BSGENOME {
    label 'process_medium'
    stageInMode 'copy'

    input:
    path forge_seed
    path seqs_srcdir

    output:
    path "BSgenome.*.tar.gz", emit: bsgenome
    path "versions.yml", emit: versions, topic: versions
    tuple val("${task.process}"), val('BSgenome'), eval('BSgenome --version'), emit: versions_forgebsg, topic: versions

    """
    forge_bsgenome.R ${forge_seed} ${seqs_srcdir}
    pkgname=`<${forge_seed} head -1 | cut -d" " -f2`
    R CMD build \${pkgname}
    R CMD check \${pkgname}*.tar.gz --no-manual

    cat <<-END_VERSIONS
    "${task.process}":
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_BSgenome: \$(Rscript -e 'packageVersion("BSgenome")' | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """
}
