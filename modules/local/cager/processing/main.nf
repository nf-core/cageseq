//
// Calling of tag clusters with CAGEr
//

process CAGER_PROCESSING {
    label 'process_verylong'
    stageInMode 'copy'

    input:
    path cager_obj
    path bsgenome_file
    val bsgenome_name
    path txdb

    output:
    path "intermediate_cagerobj/normalized_clustered_cagexp.rds",        emit: rds
    tuple path("plots/*.pdf"), path("plots/*.txt"), path("plots/*plot.rds"), emit: results
    tuple path("tracks/*.bw"), path("tracks/*.bed"), path("tables/*.csv"), emit: tracks
    path "versions.yml", emit: versions

    """
    if [ -z ${bsgenome_name} ]
    then
        bsgenome=${bsgenome_file}
    else
        bsgenome=${bsgenome_name}
    fi

    cager_processing.R  \
        --cageexp_object ${cager_obj} \
        --range_min ${params.norm_range_min} \
        --range_max ${params.norm_range_max} \
        --method ${params.norm_method} \
        --t_norm ${params.t_norm} \
        --alpha ${params.alpha} \
        --sample_num_thr ${params.sample_num_thr} \
        --ctss_thr ${params.ctss_thr} \
        --distclu_maxDist ${params.distclu_maxDist} \
        --keepSingletonsAbove ${params.keepSingletonsAbove} \
        --iq_low ${params.iq_low} \
        --iq_high ${params.iq_high} \
        --iqw_tpm_threshold ${params.iqw_tpm_threshold} \
        --consensus_thr ${params.consensus_thr} \
        --consensus_dist ${params.consensus_dist} \
        --annotation ${txdb} \
        --project_dir ${projectDir} \
        --bsgenome \${bsgenome} \
        --num_core ${task.cpus}

    cat tracks/consensusClusters_prefix.bed | awk '{print \$1 "\t" \$2 "\t" \$3 "\t" \$4 "\t" \$5 "\t" \$6 "\t" \$7 }' > tracks/consensusClusters.bed
    rm tracks/consensusClusters_prefix.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Bash: \$(echo "\$BASH_VERSION")
        R: \$(R --version | head -1 | awk '{print \$3}')
        R_CAGEr: \$(Rscript -e 'packageVersion("CAGEr")' | awk '{print \$2}' | tr -d "‘’")
    END_VERSIONS
    """
}
