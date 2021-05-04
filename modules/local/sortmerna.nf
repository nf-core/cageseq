// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process SORTMERNA {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:meta.id) }

    // Note: 2.7X indices incompatible with AWS iGenomes.
    conda (params.enable_conda ? "bioconda::sortmerna=4.2.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sortmerna:4.2.0--0"
    } else {
        container "quay.io/biocontainers/sortmerna:4.2.0--0"
    }

    input:
    tuple val(meta), path(reads)
    path  fasta
    
    output:
    tuple val(meta), path("*.fastq.gz")         , emit: reads
    tuple val(meta), path ("*report.txt")       , emit: log
    path  "*.version.txt"                       , emit: version

    script:
    fasta = fasta.collect()
    def Refs = ""
    for (i=0; i<fasta.size(); i++) { Refs+= " --ref ${fasta[i]}" }
    def software   = getSoftwareName(task.process)
    def prefix     = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    sortmerna ${Refs} \\
    --reads ${reads} \\
    --threads $task.cpus \\
    $options.args
    
    mv non-rRNA-reads.fastq ${prefix}.no_rRNA.fastq
    gzip ${prefix}.no_rRNA.fastq
    mv rRNA-reads.log ${prefix}_rRNA_report.txt

    sortmerna --version 2>&1 >/dev/null | head -n 2 | cut -d" " -f5 > ${software}.version.txt
    """
}
