#!/usr/bin/env bash

# Generate a test dataset with single-end reads

# Use single-end CAGE data from Saccharomyces cerevisiae:
# anaerobic conditions (Ana, ERR2495148) and ethanol limitation (Eth, ERR2495150).
# The data is publicly available as part of the following publication:
# Borlin, C. S., Cvetesic, N., Holland, P. et al.
# Saccharomyces cerevisiae displays a stable transcription start site
# landscape in multiple conditions
# FEMS Yeast Research, 19, foy128 (2019).
# https://doi.org/10.1093/femsyr/foy128

# The script uses the following utilities:
# - prefetch, vdb-validate, fasterq-dump: https://github.com/ncbi/sra-tools/wiki/08.-prefetch-and-fasterq-dump
# - gzip, gunzip: https://www.gzip.org/
# - seqkit: https://bioinf.shenwei.me/seqkit/

mkdir -p cageflow_test_data
cd cageflow_test_data
mkdir -p fastq
mkdir fastq/se
mkdir sacCer3_genome
cd fastq/se

# Approximate number of reads to sample randomly
readN=300000

# Download full samples
wget ftp://ftp.sra.ebi.ac.uk/vol1/run/ERR249/ERR2495148/20171106_CAGE_SequencingData_Ana_Rep1.fastq.gz
wget ftp://ftp.sra.ebi.ac.uk/vol1/run/ERR249/ERR2495150/20171106_CAGE_SequencingData_Eth_Rep1.fastq.gz

# Shuffle full samples and remove originals
seqkit shuffle -s 42 20171106_CAGE_SequencingData_Ana_Rep1.fastq.gz -o 20171106_CAGE_SequencingData_Ana_Rep1_shuff.fastq.gz
# [INFO] 9637094 sequences loaded
rm 20171106_CAGE_SequencingData_Ana_Rep1.fastq.gz
seqkit shuffle -s 42 20171106_CAGE_SequencingData_Eth_Rep1.fastq.gz -o 20171106_CAGE_SequencingData_Eth_Rep1_shuff.fastq.gz
# [INFO] 5295517 sequences loaded
rm 20171106_CAGE_SequencingData_Eth_Rep1.fastq.gz

# Take a random half of reads (after shuffling) to further subset for lane 1 of samples 1 and 2
seqkit head -n 4818547 20171106_CAGE_SequencingData_Ana_Rep1_shuff.fastq.gz -o 20171106_CAGE_SequencingData_Ana_Rep1_shuff_top-half.fastq.gz
seqkit head -n 2647758 20171106_CAGE_SequencingData_Eth_Rep1_shuff.fastq.gz -o 20171106_CAGE_SequencingData_Eth_Rep1_shuff_top-half.fastq.gz

# Take the other half of reads to further subset for lane 2 of samples 1 and 2
seqkit range -r -4818548:-1 20171106_CAGE_SequencingData_Ana_Rep1_shuff.fastq.gz -o 20171106_CAGE_SequencingData_Ana_Rep1_shuff_bottom-half.fastq.gz
seqkit range -r -2647759:-1 20171106_CAGE_SequencingData_Eth_Rep1_shuff.fastq.gz -o 20171106_CAGE_SequencingData_Eth_Rep1_shuff_bottom-half.fastq.gz

# Remove the full shuffled samples
rm 20171106_CAGE_SequencingData_Ana_Rep1_shuff.fastq.gz
rm 20171106_CAGE_SequencingData_Eth_Rep1_shuff.fastq.gz

# Randomly subsample reads for lanes 1 and 2 of samples 1 and 2
seqkit sample -p 0.1 -s 42 20171106_CAGE_SequencingData_Ana_Rep1_shuff_top-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S1_S1_L001_R1_001.fastq.gz
# See https://bioinf.shenwei.me/seqkit/note/#effect-of-random-seed-on-results-of-seqkit-sample
# on why seqkit sometimes does not output the exact number of reads that was required
rm 20171106_CAGE_SequencingData_Ana_Rep1_shuff_top-half.fastq.gz
seqkit sample -p 0.1 -s 42 20171106_CAGE_SequencingData_Ana_Rep1_shuff_bottom-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S1_S1_L002_R1_001.fastq.gz
rm 20171106_CAGE_SequencingData_Ana_Rep1_shuff_bottom-half.fastq.gz
seqkit sample -p 0.1 -s 42 20171106_CAGE_SequencingData_Eth_Rep1_shuff_top-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S2_S2_L001_R1_001.fastq.gz
rm 20171106_CAGE_SequencingData_Eth_Rep1_shuff_top-half.fastq.gz
seqkit sample -p 0.1 -s 42 20171106_CAGE_SequencingData_Eth_Rep1_shuff_bottom-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S2_S2_L002_R1_001.fastq.gz
rm 20171106_CAGE_SequencingData_Eth_Rep1_shuff_bottom-half.fastq.gz

# To get the reference genome and its annotation, use the following command:
cd ../../sacCer3_genome

wget https://hgdownload.soe.ucsc.edu/goldenPath/sacCer3/bigZips/sacCer3.fa.gz
gunzip sacCer3.fa.gz
wget https://hgdownload.soe.ucsc.edu/goldenPath/sacCer3/bigZips/genes/sacCer3.ensGene.gtf.gz
gunzip sacCer3.ensGene.gtf.gz
