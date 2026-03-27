#!/usr/local/env bash

# Full standard run, samplesheet
time ~/tools/nextflow_25.10/nextflow run \
     cageseq/main.nf \
     -params-file cageseq/testdata/tests/params_cageseq2_test_standard_samplesheet.yaml \
     -profile singularity \
     -w /mnt/scratch/slava/cageseq_test

# Full standard run, infolder
time ~/tools/nextflow_25.10/nextflow run \
     cageseq/main.nf \
     -params-file cageseq/testdata/tests/params_cageseq2_test_standard_infolder.yaml \
     -profile singularity \
     -w /mnt/scratch/slava/cageseq_test

# Full alternative run
time ~/tools/nextflow_25.10/nextflow run \
     cageseq/main.nf \
     -params-file cageseq/testdata/tests/params_cageseq2_test_alt.yaml \
     -profile singularity \
     -w /mnt/scratch/slava/cageseq_test

# Maponly run
time ~/tools/nextflow_25.10/nextflow run \
     cageseq/main.nf \
     -params-file cageseq/testdata/tests/params_cageseq2_test_maponly.yaml \
     -profile singularity \
     -w /mnt/scratch/slava/cageseq_test

# # cageronly run, star
# time ~/tools/nextflow_25.10/nextflow run \
#      cageseq/main.nf \
#      -params-file cageseq/testdata/tests/params_cageseq2_test_cageronly_star.yaml \
#      -profile singularity \
#      -w /mnt/scratch/slava/cageseq_test

# # cageronly run, bowtie
# time ~/tools/nextflow_25.10/nextflow run \
#      cageseq/main.nf \
#      -params-file cageseq/testdata/tests/params_cageseq2_test_cageronly_bowtie.yaml \
#      -profile singularity \
#      -w /mnt/scratch/slava/cageseq_test

# # cageronly run, bsgenome
# time ~/tools/nextflow_25.10/nextflow run \
#      cageseq/main.nf \
#      -params-file cageseq/testdata/tests/params_cageseq2_test_cageronly_bsgenome.yaml \
#      -profile singularity \
#      -w /mnt/scratch/slava/cageseq_test
