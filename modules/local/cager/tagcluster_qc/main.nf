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
    path "versions.yml", emit: versions

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
        --corrplot_tagCountThreshold ${params.corrplot_tagCountThreshold}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
        R_ChIPseeker: \$(Rscript -e 'packageVersion("ChIPseeker")' | tail -1 | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """
}
