// Import generic module functions
include { saveFiles } from './functions'

params.options = [:]

/*
 * Get chromosome sizes from a fasta file
 */
process CUTADAPT_TRIMMING {
    ag "$meta.id"
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:"genome", publish_id:'') }

    conda (params.enable_conda ? "bioconda::cutadapt=2.10" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/cutadapt:2.10--py38h0213d0e_1"
    } else {
        container "quay.io/biocontainers/cutadapt:2.10--py38h0213d0e_1"
    }

    input:
    tuple val(meta), path(reads)

    output:

    script:
    def prefix   = options.suffix ? "${meta.id}.${options.suffix}" : "${meta.id}"

    // Cut EcoP and Linker
    if(!params.skip_trimming && params.trim_ecop && params.trim_linker)
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
        """
    
    // Cut only EcoP
    else if(!params.skip_trimming && params.trim_ecop)
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
            
        """
    
    // Cut only linker
    else if(!params.skip_trimming && params.trim_linker)
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
        """


}