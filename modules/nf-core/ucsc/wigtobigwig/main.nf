process UCSC_WIGTOBIGWIG {
    tag "$meta.id"
    label 'process_single'

    // WARN: Version information not provided by tool on CLI. Please update version string below when bumping container versions.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ucsc-wigtobigwig:447--h2a80c09_1' :
        'biocontainers/ucsc-wigtobigwig:447--h2a80c09_1' }"

    input:
    tuple val(meta), path(wig)
    each path(sizes)

    output:
    tuple val(meta), path("*.bw"), emit: bw
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def VERSION = '447' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
     # Make a bigWig from the first wig
    wigToBigWig \\
        $args \\
        ${wig[0]} \\
        $sizes \\
        ${wig[0]}.bw

    # Make a bigWig from the second wig
    wigToBigWig \\
        $args \\
        ${wig[1]} \\
        $sizes \\
        ${wig[1]}.bw

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ucsc: $VERSION
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '447' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch ${wig[0]}.bw
    touch ${wig[1]}.bw

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ucsc: $VERSION
    END_VERSIONS
    """
}
