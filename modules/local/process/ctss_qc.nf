// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CTSS_QC {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta.id) }

    conda (params.enable_conda ? "bioconda::rseqc=3.0.1" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/rseqc:3.0.1--py37h516909a_1"
    } else {
        container "quay.io/biocontainers/rseqc:3.0.1--py37h516909a_1"
    }

    input:
    tuple val(meta), path(ctss)
    path(gtfbed)
    path(chrom_sizes)
    
    output:
    tuple val(meta), path("*")         , emit: rseqc

    script:
    def prefix     = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    gtfbed.collect()
    """
    bedtools bedtobam -i $clusters -g $chrom_sizes > ${clusters.baseName}.bam
    read_distribution.py -i ${clusters.baseName}.bam -r $gtf > ${clusters.baseName}.read_distribution.txt
    """
}
