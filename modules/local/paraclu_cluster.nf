// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process PARACLU_CLUSTER {
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:'') }

    conda (params.enable_conda ? "bioconda::paraclu" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/paraclu:9--he513fc3_0"
    } else {
        container "quay.io/biocontainers/paraclu:9--he513fc3_0"
    }

    input:
    path(ctss)
    
    output:
    path('*.bed')                            , emit: cluster

    script:

    """
    paraclu ${params.min_cluster} "ctss_all_pos_4Ps" > "ctss_all_pos_clustered"
    paraclu ${params.min_cluster} "ctss_all_neg_4Ps" > "ctss_all_neg_clustered"

    paraclu-cut  "ctss_all_pos_clustered" >  "ctss_all_pos_clustered_simplified"
    paraclu-cut  "ctss_all_neg_clustered" >  "ctss_all_neg_clustered_simplified"

    cat "ctss_all_pos_clustered_simplified" "ctss_all_neg_clustered_simplified" >  "ctss_all_clustered_simplified"
    awk -F '\t' '{print \$1"\t"\$3"\t"\$4"\t"\$1":"\$3".."\$4","\$2"\t"\$6"\t"\$2}' "ctss_all_clustered_simplified" >  "ctss_all_clustered_simplified.bed"
    """
}
