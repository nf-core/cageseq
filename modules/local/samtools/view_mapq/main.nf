process SAMTOOLS_VIEW_MAPQ {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.20--h50ea8bc_0' :
        'biocontainers/samtools:1.20--h50ea8bc_0' }"

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path("*.bam"),  emit: bam
    path  "versions.yml",            emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = "${meta.id}_mapq"
    def file_type = "bam"
    """
    samtools \\
        view \\
        --threads ${task.cpus-1} \\
        -b \\
        $args \\
        -o ${prefix}.${file_type} \\
        $input

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = "${meta.id}_mapq"
    def file_type = "bam"
    """
    touch ${prefix}.${file_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
