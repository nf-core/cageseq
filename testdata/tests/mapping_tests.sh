#!/usr/bin/env bash
paramfilespath="/mnt/biggley/home/slava/projects/leancage_dev/customcageq/testdata/tests/"

paramsfiles=(
    "params_yeast_borlin_test_star_windex_wfasta_se.yaml" \
    "params_danio_nepal_test_bt2_windex_wfasta_pe.yaml" \
    "params_danio_nepal_test_bt2_windex_nfasta_pe.yaml" \
    "params_danio_nepal_test_bt2_nindex_wfasta_pe.yaml" \
    "params_danio_nepal_test_star_windex_wfasta_pe.yaml" \
    "params_danio_nepal_test_star_windex_nfasta_pe.yaml" \
    "params_danio_nepal_test_star_nindex_wfasta_pe.yaml" \
    "params_yeast_borlin_test_bt2_windex_wfasta_se.yaml" \
    "params_yeast_borlin_test_bt2_windex_nfasta_se.yaml" \
    "params_yeast_borlin_test_bt2_nindex_wfasta_se.yaml" \
    "params_yeast_borlin_test_star_windex_nfasta_se.yaml" \
    "params_yeast_borlin_test_star_nindex_wfasta_se.yaml")

touch mapping_tests_log.txt

for pf in ${paramsfiles[@]}; do
    time ~/tools/nextflow/nextflow run \
        customcageq/main.nf \
        -params-file customcageq/testdata/tests/${pf} \
        -profile singularity \
        -w /mnt/scratch/slava/work_nepal_test && \
    echo ${pf} >> mapping_tests_log.txt && \
    find results/*_align -type f -regextype sed -regex ".*\.wig\|.*\.bam" -print | \
        xargs -L 1 basename | \
        cut -d"_" -f1 | \
        sort | \
        uniq -c >> \
        mapping_tests_log.txt && \
    rm -r results
done
