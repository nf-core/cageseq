process TAG_CLUSTER_QC {
    tag "$meta.id"
    label 'process_high'
    
    conda (params.enable_conda ? "bioconda::rseqc=3.0.0 bioconda::bedtools=2.20.1" : null)
    if (workflow.containerEngine == 'singularity' && !params.pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/mulled-v2-73efd97e29f8e7045b0bf4b2b0389399f25a885b:8a97dfb2b01dca2f366faa19a8c52c9bb0e3885e-0"
    } else {
        container "quay.io/biocontainers/mulled-v2-73efd97e29f8e7045b0bf4b2b0389399f25a885b:8a97dfb2b01dca2f366faa19a8c52c9bb0e3885e-0"
    }

    input:
    tuple val(meta), path(ctss) // channel: [ val(meta), [ ctss ] ]
    path(gtfbed)                // path: to gtf file in bed format
    path(chrom_sizes)           // path: to file with chromosome sizes
    
    output:
    tuple val(meta), path("*.txt"), emit: rseqc
    path  "versions.yml"          , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    bedtools bedtobam -i $ctss -g $chrom_sizes > ${ctss.baseName}.bam
    read_distribution.py -i ${ctss.baseName}.bam -r $gtfbed > ${ctss.baseName}.read_distribution.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
        rseqc: \$(read_distribution.py --version | sed -e "s/read_distribution.py //g")
    END_VERSIONS
    """
}
