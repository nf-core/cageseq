// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options = initOptions(params.options)

/*
 * Get chromosome sizes from a fasta file
 */
process CUTADAPT_ARTEFACT {
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
    path(artefacts_5end)
    path(artefacts_3end)

    output:
    tuple val(meta), path("*fastq.gz"),     emit: reads
    tuple val(meta), path("*output.txt"),   emit: log

    script:
    def prefix   = options.suffix ? "${meta.id}.${options.suffix}" : "${meta.id}"

    """
    cutadapt -a file:$artefacts_3end \\
    -g file:$artefacts_5end -e 0.1 --discard-trimmed \\
    --match-read-wildcards -m 15 -O 19 \\
    --cores=$task.cpus \\
    -o "${prefix}".artifacts_trimmed.fastq.gz \\
    $reads \\
    > ${prefix}.artifacts_trimming.output.txt
    """
    

     

}