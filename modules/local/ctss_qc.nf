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

    conda (params.enable_conda ? "bioconda::rseqc=3.0.0 bioconda::bedtools=2.20.1" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/mulled-v2-73efd97e29f8e7045b0bf4b2b0389399f25a885b:8a97dfb2b01dca2f366faa19a8c52c9bb0e3885e-0"
    } else {
        container "quay.io/biocontainers/mulled-v2-73efd97e29f8e7045b0bf4b2b0389399f25a885b:8a97dfb2b01dca2f366faa19a8c52c9bb0e3885e-0"
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
    bedtools bedtobam -i $ctss -g $chrom_sizes > ${ctss.baseName}.bam
    read_distribution.py -i ${ctss.baseName}.bam -r $gtfbed > ${ctss.baseName}.read_distribution.txt
    """
}
