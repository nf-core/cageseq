// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options = initOptions(params.options)

/*
 * Get chromosome sizes from a fasta file
 */
process CUTADAPT_TRIMMING {
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
    path "*version.txt",                    emit: version

    script:
    def prefix   = options.suffix ? "${meta.id}.${options.suffix}" : "${meta.id}"

    // Cut EcoP and Linker
    if(params.trim_ecop && params.trim_linker)
        """
        cutadapt -a ^${params.eco_site}...${params.linker_seq} \\
        --match-read-wildcards \\
        --minimum-length 15 --maximum-length 40 \\
        --discard-untrimmed \\
        --quality-cutoff 30 \\
        --cores=$task.cpus \\
        -o "${prefix}".adapter_trimmed.fastq.gz \\
        $reads \\
        > "${prefix}"_adapter_trimming.output.txt
        cutadapt --version > cutadapt.version.txt
        """
    
    // Cut only EcoP
    else if(params.trim_ecop)
        """
        mkdir trimmed
        cutadapt -g ^${params.eco_site} \\
        -e 0 \\
        --match-read-wildcards \\
        --minimum-length 20 --maximum-length 40 \\
        --discard-untrimmed \\
        --quality-cutoff 30 \\
        --cores=$task.cpus \\
        -o "${prefix}".adapter_trimmed.fastq.gz \\
        $reads \\
        > "${prefix}"_adapter_trimming.output.txt
        cutadapt --version > cutadapt.version.txt
        """
    
    // Cut only linker
    else if(params.trim_linker)
        """
        mkdir trimmed
        cutadapt -a ${params.linker_seq}\$ \\
        -e 0 \\
        --match-read-wildcards \\
        --minimum-length 20 --maximum-length 40 \\
        --discard-untrimmed \\
        --quality-cutoff 30 \\
        --cores=$task.cpus \\
        -o "${prefix}".adapter_trimmed.fastq.gz \\
        $reads \\
        > "${prefix}"_adapter_trimming.output.txt
        cutadapt --version > cutadapt.version.txt
        """

}