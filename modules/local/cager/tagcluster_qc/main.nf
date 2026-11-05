//
// Quality Control steps of CAGEr after clustering of CTSS
//

process CAGER_TAGCLUSTER_QC {
    label 'process_high'
    stageInMode 'copy'

    input:
    path cager_obj
    path txdb
    path bsgenome_file
    val bsgenome_name

    output:
    path "tables/*.csv", emit: counts_csv
    tuple path("plots/*plot.pdf"), path("plots/*plot.rds"), emit: plots
    path "plots/*correlations_matrix.rds", emit: correlation_rds
    path "plots/*_error.txt", emit: error_logs, optional: true
    path "versions.yml", emit: versions

    script:
    """
    echo "QC on tag and consensus clusters"
    if [ -z ${bsgenome_name} ]
    then
        bsgenome=${bsgenome_file}
    else
        bsgenome=${bsgenome_name}
    fi

    cager_tagcluster_qc.R  \
        --cageexp_object ${cager_obj} \
        --annotation ${txdb} \
        --bsgenome \${bsgenome} \
        --iq_low ${params.iq_low} \
        --iq_high ${params.iq_high} \
        --tssregion_up ${params.tssregion_up} \
        --tssregion_down ${params.tssregion_down} \
        --tsslogo_upstream ${params.tsslogo_upstream} \
        --project_dir ${projectDir} \
        --corrplot_tagCountThreshold ${params.corrplot_tagCountThreshold} \
        --ctss_thr ${params.ctss_thr} \
        --threshold_is_tpm ${params.threshold_is_tpm} \
        --sample_num_thr ${params.sample_num_thr} \
        --sort_samples ${params.sort_samples}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
        R_ChIPseeker: \$(Rscript -e 'packageVersion("ChIPseeker")' | tail -1 | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p plots tables
    for p in chipseeker_tagCluster_annotation_plot consensus_clusters_pca_plot consensus_counts_plot CTSS_pca_plot dinucleotide_frequencies_all_tss_plot dinucleotide_frequencies_plot norm_CTSS_correlations_plot stub_tagcluster_dominantTSSlogos_plot; do
        touch plots/\$p.pdf plots/\$p.rds
    done
    touch plots/norm_CTSS_correlations_matrix.rds
    touch tables/consensus_clusters_tpm.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
        R_ChIPseeker: \$(Rscript -e 'packageVersion("ChIPseeker")' | tail -1 | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """
}
