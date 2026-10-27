#!/usr/bin/env bash
paramfilespath="/mnt/biggley/home/slava/projects/leancage_dev/customcageq/testdata/tests/"

paramsfiles=(
    "params_yeast_borlin_test_star_windex_wfasta_dedup_se.yaml" \
    "params_danio_nepal_test_bt2_windex_wfasta_dedup_pe.yaml" \
    "params_danio_nepal_test_star_windex_wfasta_dedup_pe.yaml" \
    "params_yeast_borlin_test_bt2_windex_wfasta_dedup_se.yaml" \
    "params_yeast_borlin_test_star_windex_wfasta_dedup_dist_se.yaml" \
    "params_danio_nepal_test_bt2_windex_wfasta_dedup_dist_pe.yaml" \
    "params_danio_nepal_test_star_windex_wfasta_dedup_dist_pe.yaml" \
    "params_yeast_borlin_test_bt2_windex_wfasta_dedup_dist_se.yaml")

touch dedup_tests_log.txt

for pf in ${paramsfiles[@]}; do
    time ~/tools/nextflow/nextflow run \
        customcageq/main.nf \
        -params-file customcageq/testdata/tests/${pf} \
        -profile singularity \
        -w /mnt/scratch/slava/work_nepal_test && \
    echo ${pf} >> dedup_tests_log.txt && \
    ls -l results/*_dedup 2>&1 >> \
        dedup_tests_log.txt && \
    rm -r results
done
