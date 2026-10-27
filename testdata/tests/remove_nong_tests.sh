#!/usr/bin/env bash
paramfilespath="/mnt/biggley/home/slava/projects/leancage_dev/customcageq/testdata/tests/"

paramsfiles=(
    "params_danio_nepal_test_bt2_windex_wfasta_removenong_pe.yaml" \
    "params_yeast_borlin_test_bt2_windex_wfasta_removenong_se.yaml" )

touch mapping_removenong_tests_log.txt

for pf in ${paramsfiles[@]}; do
    time ~/tools/nextflow/nextflow run \
        customcageq/main.nf \
        -params-file customcageq/testdata/tests/${pf} \
        -profile singularity \
        -w /mnt/scratch/slava/work_nepal_test && \
    echo ${pf} >> mapping_removenong_tests_log.txt && \
    mv results results_${pf%%.yaml}
done
