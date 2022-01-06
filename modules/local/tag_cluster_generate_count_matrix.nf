process TAG_CLUSTER_GENERATE_COUNT_MATRIX {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::coreutils=8.31" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/coreutils:8.31--h14c3975_0"
    } else {
        container "quay.io/biocontainers/coreutils:8.31--h14c3975_0"
    }

    input:
    path(counts)    // path to bed files with per sample count of clusters
    path(clusters)  // path to bed file with cluster coordinates

    output:
    path("*.tsv")           , emit: count_table
    path  "versions.yml"    , emit: versions
    script:
    """
    echo 'coordinates' > coordinates
    cut -f 4 $clusters >> coordinates

    paste -d "\t" coordinates $counts >> count_table.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        coreutils: \$(paste --version | head -n1  | sed 's/^.*paste (GNU coreutils) //')
    END_VERSIONS
    """
}
