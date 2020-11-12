// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process BIGWIG_CREATE {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta.id) }

    conda (params.enable_conda ? "bioconda::bedtools=2.26.0gx" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/quay.io/biocontainers/bedtools:2.26.0gx--he513fc3_4"
    } else {
        container "quay.io/biocontainers/bedtools:2.26.0gx--he513fc3_4"
    }

    input:
    tuple val(meta), path(ctss)
    path(chrom_sizes)
    
    output:
    tuple val(meta), path("*.ctss.bw")         , emit: bigwig

    script:
    def prefix     = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    bedtools genomecov -bg -i ${ctss} -g ${chrom_sizes} > ${prefix}.bedgraph
    sort -k1,1 -k2,2n ${prefix}.bedgraph > ${prefix}_sorted.bedgraph
    bedGraphToBigWig ${prefix}_sorted.bedgraph ${chrom_sizes} ${prefix}.ctss.bw
    """
}
