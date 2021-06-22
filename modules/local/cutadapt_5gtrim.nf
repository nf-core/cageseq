// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options = initOptions(params.options)

/*
 * Get chromosome sizes from a fasta file
 */
process CUTADAPT_5GTRIM {
    tag "$meta.id"
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:'') }

    conda (params.enable_conda ? "bioconda::cutadapt=2.10" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/cutadapt:2.10--py38h0213d0e_1"
    } else {
        container "quay.io/biocontainers/cutadapt:2.10--py38h0213d0e_1"
    }

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*fastq.gz"),     emit: reads
    tuple val(meta), path("*output.txt"),   emit: log

    script:
    def prefix   = options.suffix ? "${meta.id}.${options.suffix}" : "${meta.id}"

    """
    cutadapt -g ^G \\
    -e 0 --match-read-wildcards \\
    --cores=$task.cpus \\
    -o "${prefix}".g_trimmed.fastq.gz \\
    $reads \\
    > "${prefix}".g_trimming.output.txt
    """
    

     

}