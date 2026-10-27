process FORGEBSGENOME {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-bsgenome:1.70.1--r43hdfd78af_0':
        'biocontainers/bioconductor-bsgenome:1.70.1--r43hdfd78af_0' }"

    input:
    tuple val(meta), path(forge_seed)
    path seqs_fasta

    output:
    tuple val(meta), path("*.tar.gz"),  emit: tarball
    tuple val(meta), path("*.Rcheck"),  emit: check_results, optional: true
    path "versions.yml", emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template 'forge_bsgenome.R'

    stub:
    """
    touch genome.tar.gz
    touch test.Rcheck
    cat <<-END_VERSIONS > versions.yml
       "${task.process}":
           R: \$(R --version | head -1 | awk '{print \$3}')
           R_txdbmaker: \$(Rscript -e 'packageVersion("txdbmaker")' | awk '{print \$2}' | tr -d "‘’")
       END_VERSIONS

    """
}
