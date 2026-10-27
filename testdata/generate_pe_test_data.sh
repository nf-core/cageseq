#!/usr/bin/env bash

# Generate a test dataset with paired-end reads

# Use paired-end CAGE data from Danio rerio:
# 4-5 somites (SRR10215487) and prim-5 (SRR10215486).
# The data is publicly available as part of the following publication:
# Nepal, C., Hadzhiev, Y., Balwierz, P. et al.
# Dual-initiation promoters with intertwined canonical and TCT/TOP
# transcription start sites diversify transcript processing.
# Nat Commun 11, 168 (2020).
# https://doi.org/10.1038/s41467-019-13687-0

# The script uses the following utilities:
# - prefetch, vdb-validate, fasterq-dump: https://github.com/ncbi/sra-tools/wiki/08.-prefetch-and-fasterq-dump
# - gzip, gunzip: https://www.gzip.org/
# - seqkit: https://bioinf.shenwei.me/seqkit/

mkdir -p cageflow_test_data
cd cageflow_test_data
mkdir -p fastq
mkdir fastq/pe
mkdir danRer11_genome
cd fastq/pe

# Approximate number of reads to sample randomly
readN=1000000

# Download and dump full samples
prefetch SRR10215487 SRR10215486 && \
vdb-validate SRR* && \
for srr in SRR*; do fasterq-dump ${srr}; done

# Prepare the data for processing
echo "Rename and gzip full sample FASTQs..."
echo "SRR10215487_1..."
mv SRR10215487_1.fastq 4somites_SRR10215487_1.fastq
gzip 4somites_SRR10215487_1.fastq
echo "SRR10215487_2..."
mv SRR10215487_2.fastq 4somites_SRR10215487_2.fastq
gzip 4somites_SRR10215487_2.fastq
echo "SRR10215486_1..."
mv SRR10215486_1.fastq prim5_SRR10215486_1.fastq
gzip prim5_SRR10215486_1.fastq
echo "SRR10215486_2..."
mv SRR10215486_2.fastq prim5_SRR10215486_2.fastq
gzip prim5_SRR10215486_2.fastq

# Remove directories with the downloaded SRAs
rm -r SRR10215487 SRR10215486

# Shuffle full samples and remove originals
seqkit shuffle -s 42 4somites_SRR10215487_1.fastq.gz -o 4somites_SRR10215487_1_shuff.fastq.gz
# [INFO] 7780967 sequences loaded
rm 4somites_SRR10215487_1.fastq.gz
seqkit shuffle -s 42 4somites_SRR10215487_2.fastq.gz -o 4somites_SRR10215487_2_shuff.fastq.gz
# [INFO] 7780967 sequences loaded
rm 4somites_SRR10215487_2.fastq.gz
seqkit shuffle -s 42 prim5_SRR10215486_1.fastq.gz -o prim5_SRR10215486_1_shuff.fastq.gz
# [INFO] 13565767 sequences loaded
rm prim5_SRR10215486_1.fastq.gz
seqkit shuffle -s 42 prim5_SRR10215486_2.fastq.gz -o prim5_SRR10215486_2_shuff.fastq.gz
# [INFO] 13565767 sequences loaded
rm prim5_SRR10215486_2.fastq.gz

# Take a random half of reads (after shuffling) to further subset for lane 1 of sample 1
seqkit head -n 3890483 4somites_SRR10215487_1_shuff.fastq.gz -o 4somites_SRR10215487_1_shuff_top-half.fastq.gz
seqkit head -n 3890483 4somites_SRR10215487_2_shuff.fastq.gz -o 4somites_SRR10215487_2_shuff_top-half.fastq.gz

# Take the other half of reads to further subset for lane 2 of sample 1
seqkit range -r -3890484:-1 4somites_SRR10215487_1_shuff.fastq.gz -o 4somites_SRR10215487_1_shuff_bottom-half.fastq.gz
seqkit range -r -3890484:-1 4somites_SRR10215487_2_shuff.fastq.gz -o 4somites_SRR10215487_2_shuff_bottom-half.fastq.gz

# Remove the full sample subset above
rm 4somites_SRR10215487_1_shuff.fastq.gz
rm 4somites_SRR10215487_2_shuff.fastq.gz

# Take a random half of reads (after shuffling) to further subset for lane 1 of sample 2
seqkit head -n 6782883 prim5_SRR10215486_1_shuff.fastq.gz -o prim5_SRR10215486_1_shuff_top-half.fastq.gz
seqkit head -n 6782883 prim5_SRR10215486_2_shuff.fastq.gz -o prim5_SRR10215486_2_shuff_top-half.fastq.gz

# Take the other half of reads to further subset for lane 2 of sample 2
seqkit range -r -6782884:-1 prim5_SRR10215486_1_shuff.fastq.gz -o prim5_SRR10215486_1_shuff_bottom-half.fastq.gz
seqkit range -r -6782884:-1 prim5_SRR10215486_2_shuff.fastq.gz -o prim5_SRR10215486_2_shuff_bottom-half.fastq.gz

# Remove the full sample subset above
rm prim5_SRR10215486_1_shuff.fastq.gz
rm prim5_SRR10215486_2_shuff.fastq.gz

# Randomly subsample reads for lane 1 of sample 1
seqkit sample -p 0.1 -s 42 4somites_SRR10215487_1_shuff_top-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S10_L001_R1.fastq.gz
# See https://bioinf.shenwei.me/seqkit/note/#effect-of-random-seed-on-results-of-seqkit-sample
# on why seqkit sometimes does not output the exact number of reads that was required
seqkit sample -p 0.1 -s 42 4somites_SRR10215487_2_shuff_top-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S10_L001_R2.fastq.gz

# Remove the subset top half
rm 4somites_SRR10215487_1_shuff_top-half.fastq.gz
rm 4somites_SRR10215487_2_shuff_top-half.fastq.gz

# Randomly subsample reads for lane 2 of sample 1
seqkit sample -p 0.1 -s 42 4somites_SRR10215487_1_shuff_bottom-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S10_L002_R1.fastq.gz
seqkit sample -p 0.1 -s 42 4somites_SRR10215487_2_shuff_bottom-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S10_L002_R2.fastq.gz

# Remove the subset bottom half
rm 4somites_SRR10215487_1_shuff_bottom-half.fastq.gz
rm 4somites_SRR10215487_2_shuff_bottom-half.fastq.gz

# Randomly subsample reads for lane 1 of sample 2
seqkit sample -p 0.1 -s 42 prim5_SRR10215486_1_shuff_top-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S14_L001_R1.fastq.gz
seqkit sample -p 0.1 -s 42 prim5_SRR10215486_2_shuff_top-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S14_L001_R2.fastq.gz

# Remove the subset top half
rm prim5_SRR10215486_1_shuff_top-half.fastq.gz
rm prim5_SRR10215486_2_shuff_top-half.fastq.gz

# Randomly subsample reads for lane 2 of sample 2
seqkit sample -p 0.1 -s 42 prim5_SRR10215486_1_shuff_bottom-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S14_L002_R1.fastq.gz
seqkit sample -p 0.1 -s 42 prim5_SRR10215486_2_shuff_bottom-half.fastq.gz | seqkit sample -n ${readN} -s 42 -o S14_L002_R2.fastq.gz

# Remove the subset bottom half
rm prim5_SRR10215486_1_shuff_bottom-half.fastq.gz
rm prim5_SRR10215486_2_shuff_bottom-half.fastq.gz

# To get the reference genome and its annotation, use the following command:
cd ../../danRer11_genome

wget https://hgdownload.soe.ucsc.edu/goldenPath/danRer11/bigZips/danRer11.fa.gz
gunzip danRer11.fa.gz
wget https://hgdownload.soe.ucsc.edu/goldenPath/danRer11/bigZips/genes/danRer11.ensGene.gtf.gz
gunzip danRer11.ensGene.gtf.gz
