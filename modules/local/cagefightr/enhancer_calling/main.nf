//
// Calling of enhancers with CAGEfightr
//

process CAGEFIGHTR_ENHANCER_CALLING {
    label 'process_verylong'
    stageInMode 'copy'

    input:
    path cager_obj
    path txdb

    output:
    tuple path("intermediate_cagerobj/supported_enhancers.rds"), path("intermediate_cagerobj/nonTSS_enhancers.rds"), emit: rds
    tuple path("plots/*.pdf"), path("plots/*plot.rds"), emit: plots
    tuple path("tables/*.tsv"), path("tracks/*.bed"), emit: enhancer_table
    path "plots/*_error.txt", emit: error_logs, optional: true
    path "versions.yml", emit: versions
    script:
    """

    echo "Calling enhancers with CAGEfightR."
    cagefightr_enhancer_calling.R  \
        --cageexp_object ${cager_obj} \
        --annotation ${txdb} \
        --cfBalanceThreshold ${params.cfBalanceThreshold} \
        --unexpressed ${params.unexpressed} \
        --minSamples ${params.minSamples} \
        --tssregion_up ${params.tssregion_up} \
        --tssregion_down ${params.tssregion_down} \
        --sort_samples ${params.sort_samples} \
        --project_dir ${projectDir}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
        R_CAGEfightR: \$(Rscript -e 'packageVersion("CAGEfightR")' | tail -1 | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p intermediate_cagerobj plots tables tracks
    touch intermediate_cagerobj/supported_enhancers.rds intermediate_cagerobj/nonTSS_enhancers.rds
    for p in chipseeker_enhancer_annotation_plot enhancer_count_per_sample_plot enhancer_expression_pca_plot; do
        touch plots/\$p.pdf plots/\$p.rds
    done
    touch tables/enhancer_expression_per_sample.tsv
    touch tracks/enhancers.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
        R_CAGEfightR: \$(Rscript -e 'packageVersion("CAGEfightR")' | tail -1 | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """
}
