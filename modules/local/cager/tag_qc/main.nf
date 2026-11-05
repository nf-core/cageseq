//
// Quality Control steps of CAGEr
//

process CAGER_TAG_QC {
    label 'process_verylong'
    stageInMode 'copy'

    input:
    path cager_obj
    path txdb
    path bsgenome_file
    val bsgenome_name

    output:
    path "intermediate_cagerobj/annotated_cagexp.rds", emit: cager_rds
    path "plots/*correlations_matrix.rds", emit: correlation_rds
    tuple path("plots/*plot.pdf"), path("plots/*plot.rds"), emit: plots
    path "versions.yml", emit: versions

    script:
    """
    echo "Initial QC on CAGEr tags"
    if [ -z ${bsgenome_name} ]
    then
        bsgenome=${bsgenome_file}
    else
        bsgenome=${bsgenome_name}
    fi

    cager_tag_qc.R  \
        --cageexp_object ${cager_obj} \
        --annotation ${txdb} \
        --bsgenome \${bsgenome} \
        --corrplot_tagCountThreshold ${params.corrplot_tagCountThreshold} \
        --project_dir ${projectDir}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p intermediate_cagerobj plots
    touch intermediate_cagerobj/annotated_cagexp.rds
    touch plots/CTSS_correlations_matrix.rds
    touch plots/CTSS_correlations_plot.pdf plots/CTSS_correlations_plot.rds
    touch plots/tag_region_annotation_plot.pdf plots/tag_region_annotation_plot.rds

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """
}
