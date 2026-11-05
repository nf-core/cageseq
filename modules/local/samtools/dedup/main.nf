process SAMTOOLS_DEDUP {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.bam"), emit: bam
    path "*_dedup_stats.txt"      , emit: txt
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    args = params.dist ? "${args} -d ${params.dist}" : args
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools \\
        markdup \\
        $args \\
        -s -f ${prefix}_dedup_stats.txt \\
        -@ $task.cpus \\
        $bam \\
        ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools_dedup: \$(samtools --version |& sed '1!d ; s/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bam
    touch ${prefix}_dedup_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools_dedup: \$(samtools --version |& sed '1!d ; s/samtools //')
    END_VERSIONS
    """
}
