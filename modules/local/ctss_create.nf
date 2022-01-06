//
// convert bam to ctss bed files
//

process CTSS_CREATE {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bedtools=2.27.0 conda-forge::gawk=5.1.0 bioconda::grep=2.14" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-22105f082fdf56207f1dcc5b6da71a14394e28d7:387d955c0a2cdb831ec519d636e4ffd7062d6ae1-0':
        'quay.io/biocontainers/mulled-v2-22105f082fdf56207f1dcc5b6da71a14394e28d7:387d955c0a2cdb831ec519d636e4ffd7062d6ae1-0' }"

    input:
    tuple val(meta), path(bed) // channel: [ val(meta), [ bed ] ]

    output:
    tuple val(meta), path("*.bed"), emit: ctss
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """

    # generate ctss on the positive strand
    awk 'BEGIN{OFS="\t"}{if(\$6=="+"){print \$1,\$2,\$5}}' $bed | \\
    sort -k1,1 -k2,2n | \\
    bedtools groupby -i stdin -g 1,2 -c 3 -o count | \\
    awk -v x="$prefix" 'BEGIN{OFS="\t"}{print \$1,\$2,\$2+1,  x  ,\$3,"+"}' > ${prefix}.pos_ctss

    # generate ctss on the negative strand
    awk 'BEGIN{OFS="\t"}{if(\$6=="-"){print \$1,\$3,\$5}}' $bed | \\
    sort -k1,1 -k2,2n | \\
    bedtools groupby -i stdin -g 1,2 -c 3 -o count | \\
    awk -v x="$prefix" 'BEGIN{OFS="\t"}{print \$1,\$2-1,\$2,  x  ,\$3,"-"}' > ${prefix}.neg_ctss

    cat ${prefix}.pos_ctss ${prefix}.neg_ctss | sort -k1,1 -k2,2n > ${prefix}.ctss.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
        gawk: \$(echo \$(gawk --version 2>&1) | sed 's/^.*GNU Awk //; s/, .*\$//')
    END_VERSIONS
    """
}
