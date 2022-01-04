process BEDTOBEDGRAPH_BYSTRAND {
    tag "$meta.id"
    label 'process_medium'
    
    conda (params.enable_conda ? "onda-forge::gawk=5.1.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.1.0' :
        'quay.io/biocontainers/gawk:5.1.0' }"
    
    input:
    tuple val(meta), path(ctss)
    
    output:
    tuple val(meta), path("*.pos.bedgraph") , emit: pos_bedgraph
    tuple val(meta), path("*.neg.bedgraph") , emit: neg_bedgraph
    path  "versions.yml"                , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    
    
    awk '\$6=="+"' $ctss > ${prefix}.pos.bed
    awk '\$6=="-"' $ctss > ${prefix}.neg.bed
    awk '{ print \$1"\t"\$2"\t"\$3"\t"\$5 }' ${prefix}.pos.bed > ${prefix}.pos.bedgraph
    awk '{ print \$1"\t"\$2"\t"\$3"\t"\$5 }' ${prefix}.neg.bed > ${prefix}.neg.bedgraph
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(echo \$(gawk --version 2>&1) | sed 's/^.*GNU Awk //; s/, .*\$//')
    END_VERSIONS

    """
}
