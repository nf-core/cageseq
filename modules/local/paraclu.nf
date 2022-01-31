def VERSION = '10' // Version information not provided by tool on CLI

process PARACLU {
    label 'process_low'

    conda (params.enable_conda ? "bioconda::paraclu=10" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/paraclu%3A10--h9a82719_1' :
        'quay.io/biocontainers/paraclu:10--h9a82719_1' }"

    input:
    path(bed) // path: of pooled ctss file
    val(min_cluster) // integer: minimum cluster size

    output:
    path("*.bed"), emit: bed
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    #  "BED into minus and positive"
    sed '/+/d' $bed > all_neg
    grep + $bed > all_pos

    #  "CTSS output to paraclu format"
    awk -F "\t" '{print\$1"\t"\$6"\t"\$2"\t"\$5}' < all_pos > ctss_pos_4P
    awk -F "\t" '{print\$1"\t"\$6"\t"\$3"\t"\$5}' < all_neg > ctss_neg_4P

    #  "Sorting the positive prior paraclu clustering"ls
    sort -k1,1 -k3n ctss_pos_4P > ctss_all_pos_4Ps

    #  "Sorting the negative prior paraclu clustering"
    sort -k1,1 -k3n ctss_neg_4P > ctss_all_neg_4Ps

    paraclu $min_cluster ctss_all_pos_4Ps > ctss_all_pos.clustered
    paraclu $min_cluster ctss_all_neg_4Ps > ctss_all_neg.clustered

    paraclu-cut  ctss_all_pos.clustered >  ctss_all_pos.clustered.simplified
    paraclu-cut  ctss_all_neg.clustered >  ctss_all_neg.clustered.simplified
    cat ctss_all_pos.clustered.simplified ctss_all_neg.clustered.simplified > ctss_all.clustered.simplified
    awk -F '\t' '{print \$1"\t"\$3"\t"\$4"\t"\$1":"\$3".."\$4","\$2"\t"\$6"\t"\$2}' ctss_all.clustered.simplified >  ctss.clustered.simplified.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        paraclu: $VERSION
    END_VERSIONS
    """
}
