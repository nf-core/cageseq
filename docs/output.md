# nf-core/cageseq: Output

## Introduction

This document describes the output produced by the pipeline.
The directories listed below will be created in the results directory after the pipeline has finished.
All paths are relative to the top-level results directory.

Reads can be mapped using `STAR` (to take splacing into account and to obtain bigWig files with raw 5'-coverage; `STAR` is used by default) or `bowtie2` (see the `--bowtie2` option below).
The pipeline can generate a genome index on the fly if provided with a FASTA file.
For genome generation with `STAR`, user can also provide a GTF file.
Apart from the CAGEexp object and raw 5'-coverage bigWig files (if reads were mapped with `STAR`), the pipeline produces BAM files with filtered alignments that could be used for a separate analysis and a detailed `MultiQC` report.

## Output

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:
TODO: clean-up

- [FastQC](#fastqc) - Raw read QC
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

### Content of the results folder

Below is the complete tree of the results run on 2 samples with the STAR option.

```
├── bigwig
│   ├── <sample_name_1>.Signal.Unique.str1.out.wig.bw
│   ├── <sample_name_1>.Signal.Unique.str2.out.wig.bw
│   ├── <sample_name_2>.Signal.Unique.str1.out.wig.bw
│   ├── <sample_name_2>.Signal.Unique.str2.out.wig.bw
│   └── versions.yml
├── cager
│   ├── cager_report.html
│   ├── intermediate_cagerobj
│   │   ├── annotated_cagexp.rds
│   │   ├── initial_cagexp.rds
│   │   ├── nonTSS_enhancers.rds
│   │   ├── normalized_clustered_cagexp.rds
│   │   └── supported_enhancers.rds
│   ├── plots
│   │   ├── chipseeker_enhancer_annotation_plot.pdf
│   │   ├── chipseeker_enhancer_annotation_plot.rds
│   │   ├── chipseeker_tagCluster_annotation_plot.pdf
│   │   ├── chipseeker_tagCluster_annotation_plot.rds
│   │   ├── consensus_clusters_pca_plot.pdf
│   │   ├── consensus_clusters_pca_plot.rds
│   │   ├── consensus_counts_plot.pdf
│   │   ├── consensus_counts_plot.rds
│   │   ├── CTSS_correlations_matrix.rds
│   │   ├── CTSS_correlations_plot.pdf
│   │   ├── CTSS_correlations_plot.rds
│   │   ├── CTSS_pca_plot.pdf
│   │   ├── CTSS_pca_plot.rds
│   │   ├── dinucleotide_frequencies_plot.pdf
│   │   ├── dinucleotide_frequencies_plot.rds
│   │   ├── enhancer_count_per_sample_plot.pdf
│   │   ├── enhancer_count_per_sample_plot.rds
│   │   ├── enhancer_expression_pca_plot.pdf
│   │   ├── enhancer_expression_pca_plot.rds
│   │   ├── interquartile_width_tagclusters_plot.pdf
│   │   ├── interquartile_width_tagclusters_plot.rds
│   │   ├── norm_CTSS_correlations_matrix.rds
│   │   ├── norm_CTSS_correlations_plot.pdf
│   │   ├── norm_CTSS_correlations_plot.rds
│   │   ├── reverse_cumulative_plot.pdf
│   │   ├── reverse_cumulative_plot.rds
│   │   ├── <sample_name_1>\_tagcluster_dominantTSSlogos_plot.pdf
│   │   ├── <sample_name_1>\_tagcluster_dominantTSSlogos_plot.rds
│   │   ├── <sample_name_2>\_tagcluster_dominantTSSlogos_plot.pdf
│   │   ├── <sample_name_2>\_tagcluster_dominantTSSlogos_plot.rds
│   │   ├── sample_tag_cluster_count.txt
│   │   ├── tag_clusters_counts_plot.pdf
│   │   ├── tag_clusters_counts_plot.rds
│   │   ├── tag_region_annotation_plot.pdf
│   │   └── tag_region_annotation_plot.rds
│   ├── tables
│   │   ├── consensus_cluster_per_sample_ctss.csv
│   │   ├── consensus_clusters_tpm.csv
│   │   └── enhancer_expression_per_sample.tsv
│   ├── tracks
│   │   ├── consensusClusters.bed
│   │   ├── enhancers.bed
│   │   ├── <sample_name_1>\_normalized_minus.bw
│   │   ├── <sample_name_1>\_normalized_plus.bw
│   │   ├── <sample_name_1>\_raw_minus.bw
│   │   ├── <sample_name_1>\_raw_plus.bw
│   │   ├── <sample_name_1>\_tagClusters.bed
│   │   ├── <sample_name_2>\_normalized_minus.bw
│   │   ├── <sample_name_2>\_normalized_plus.bw
│   │   ├── <sample_name_2>\_raw_minus.bw
│   │   ├── <sample_name_2>\_raw_plus.bw
│   │   └── <sample_name_2>\_tagClusters.bed
│   └── versions.yml
├── cat_fastq
│   ├── <sample_name_1>\_1.merged.fastq.gz
│   ├── <sample_name_1>\_2.merged.fastq.gz
│   ├── <sample_name_2>\_1.merged.fastq.gz
│   └── <sample_name_2>\_2.merged.fastq.gz
├── chrom_sizes_and_fai
│   ├── <genome_name>.fa.fai
│   ├── <genome_name>.fa.sizes
│   └── versions.yml
├── cutadapt
│   ├── <sample_name_1>.cutadapt.log
│   ├── <sample_name_1>\_R1_gtrimmed.fastq.gz
│   ├── <sample_name_1>\_R2_gtrimmed.fastq.gz
│   ├── <sample_name_2>.cutadapt.log
│   ├── <sample_name_2>\_R1_gtrimmed.fastq.gz
│   ├── <sample_name_2>\_R2_gtrimmed.fastq.gz
│   └── versions.yml
├── fastqc
│   ├── <sample_name_1>\_1_fastqc.html
│   ├── <sample_name_1>\_1_fastqc.zip
│   ├── <sample_name_1>\_2_fastqc.html
│   ├── <sample_name_1>\_2_fastqc.zip
│   ├── <sample_name_2>\_1_fastqc.html
│   ├── <sample_name_2>\_1_fastqc.zip
│   ├── <sample_name_2>\_2_fastqc.html
│   ├── <sample_name_2>\_2_fastqc.zip
│   └── versions.yml
├── multiqc
│   ├── multiqc_data
│   │   ├── mqc_cutadapt_filtered_reads_plot_1.txt
│   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Counts.txt
│   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Obs_Exp.txt
│   │   ├── mqc_fastqc_adapter_content_plot_1.txt
│   │   ├── mqc_fastqc_overrepresented_sequences_plot_1.txt
│   │   ├── mqc_fastqc_overrepresented_sequences_plot-2_1.txt
│   │   ├── mqc_fastqc_per_base_n_content_plot_1.txt
│   │   ├── mqc_fastqc_per_base_n_content_plot-2_1.txt
│   │   ├── mqc_fastqc_per_base_sequence_quality_plot_1.txt
│   │   ├── mqc_fastqc_per_base_sequence_quality_plot-2_1.txt
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Counts.txt
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Percentages.txt
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Counts.txt
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Percentages.txt
│   │   ├── mqc_fastqc_per_sequence_quality_scores_plot_1.txt
│   │   ├── mqc_fastqc_per_sequence_quality_scores_plot-2_1.txt
│   │   ├── mqc_fastqc_sequence_counts_plot_1.txt
│   │   ├── mqc_fastqc_sequence_counts_plot-2_1.txt
│   │   ├── mqc_fastqc_sequence_duplication_levels_plot_1.txt
│   │   ├── mqc_fastqc_sequence_duplication_levels_plot-2_1.txt
│   │   ├── mqc_fastqc_sequence_length_distribution_plot_1.txt
│   │   ├── mqc_samtools_alignment_plot_1.txt
│   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Normalised_Counts.txt
│   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Observed_over_Expected_Counts.txt
│   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Raw_Counts.txt
│   │   ├── mqc_star_alignment_plot_1.txt
│   │   ├── multiqc_citations.txt
│   │   ├── multiqc_cutadapt.txt
│   │   ├── multiqc_data.json
│   │   ├── multiqc_fastqc_1.txt
│   │   ├── multiqc_fastqc.txt
│   │   ├── multiqc_general_stats.txt
│   │   ├── multiqc.log
│   │   ├── multiqc_samtools_flagstat.txt
│   │   ├── multiqc_samtools_idxstats.txt
│   │   ├── multiqc_samtools_stats.txt
│   │   ├── multiqc_sources.txt
│   │   └── multiqc_star.txt
│   ├── multiqc_plots
│   │   ├── pdf
│   │   │   ├── mqc_cutadapt_filtered_reads_plot_1_pc.pdf
│   │   │   ├── mqc_cutadapt_filtered_reads_plot_1.pdf
│   │   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Counts.pdf
│   │   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Obs_Exp.pdf
│   │   │   ├── mqc_fastqc_adapter_content_plot_1.pdf
│   │   │   ├── mqc_fastqc_overrepresented_sequences_plot_1.pdf
│   │   │   ├── mqc_fastqc_overrepresented_sequences_plot-2_1.pdf
│   │   │   ├── mqc_fastqc_per_base_n_content_plot_1.pdf
│   │   │   ├── mqc_fastqc_per_base_n_content_plot-2_1.pdf
│   │   │   ├── mqc_fastqc_per_base_sequence_quality_plot_1.pdf
│   │   │   ├── mqc_fastqc_per_base_sequence_quality_plot-2_1.pdf
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Counts.pdf
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Percentages.pdf
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Counts.pdf
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Percentages.pdf
│   │   │   ├── mqc_fastqc_per_sequence_quality_scores_plot_1.pdf
│   │   │   ├── mqc_fastqc_per_sequence_quality_scores_plot-2_1.pdf
│   │   │   ├── mqc_fastqc_sequence_counts_plot_1_pc.pdf
│   │   │   ├── mqc_fastqc_sequence_counts_plot_1.pdf
│   │   │   ├── mqc_fastqc_sequence_counts_plot-2_1_pc.pdf
│   │   │   ├── mqc_fastqc_sequence_counts_plot-2_1.pdf
│   │   │   ├── mqc_fastqc_sequence_duplication_levels_plot_1.pdf
│   │   │   ├── mqc_fastqc_sequence_duplication_levels_plot-2_1.pdf
│   │   │   ├── mqc_fastqc_sequence_length_distribution_plot_1.pdf
│   │   │   ├── mqc_samtools_alignment_plot_1_pc.pdf
│   │   │   ├── mqc_samtools_alignment_plot_1.pdf
│   │   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Normalised_Counts.pdf
│   │   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Observed_over_Expected_Counts.pdf
│   │   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Raw_Counts.pdf
│   │   │   ├── mqc_star_alignment_plot_1_pc.pdf
│   │   │   └── mqc_star_alignment_plot_1.pdf
│   │   ├── png
│   │   │   ├── mqc_cutadapt_filtered_reads_plot_1_pc.png
│   │   │   ├── mqc_cutadapt_filtered_reads_plot_1.png
│   │   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Counts.png
│   │   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Obs_Exp.png
│   │   │   ├── mqc_fastqc_adapter_content_plot_1.png
│   │   │   ├── mqc_fastqc_overrepresented_sequences_plot_1.png
│   │   │   ├── mqc_fastqc_overrepresented_sequences_plot-2_1.png
│   │   │   ├── mqc_fastqc_per_base_n_content_plot_1.png
│   │   │   ├── mqc_fastqc_per_base_n_content_plot-2_1.png
│   │   │   ├── mqc_fastqc_per_base_sequence_quality_plot_1.png
│   │   │   ├── mqc_fastqc_per_base_sequence_quality_plot-2_1.png
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Counts.png
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Percentages.png
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Counts.png
│   │   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Percentages.png
│   │   │   ├── mqc_fastqc_per_sequence_quality_scores_plot_1.png
│   │   │   ├── mqc_fastqc_per_sequence_quality_scores_plot-2_1.png
│   │   │   ├── mqc_fastqc_sequence_counts_plot_1_pc.png
│   │   │   ├── mqc_fastqc_sequence_counts_plot_1.png
│   │   │   ├── mqc_fastqc_sequence_counts_plot-2_1_pc.png
│   │   │   ├── mqc_fastqc_sequence_counts_plot-2_1.png
│   │   │   ├── mqc_fastqc_sequence_duplication_levels_plot_1.png
│   │   │   ├── mqc_fastqc_sequence_duplication_levels_plot-2_1.png
│   │   │   ├── mqc_fastqc_sequence_length_distribution_plot_1.png
│   │   │   ├── mqc_samtools_alignment_plot_1_pc.png
│   │   │   ├── mqc_samtools_alignment_plot_1.png
│   │   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Normalised_Counts.png
│   │   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Observed_over_Expected_Counts.png
│   │   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Raw_Counts.png
│   │   │   ├── mqc_star_alignment_plot_1_pc.png
│   │   │   └── mqc_star_alignment_plot_1.png
│   │   └── svg
│   │   ├── mqc_cutadapt_filtered_reads_plot_1_pc.svg
│   │   ├── mqc_cutadapt_filtered_reads_plot_1.svg
│   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Counts.svg
│   │   ├── mqc_cutadapt_trimmed_sequences_plot_3_Obs_Exp.svg
│   │   ├── mqc_fastqc_adapter_content_plot_1.svg
│   │   ├── mqc_fastqc_overrepresented_sequences_plot_1.svg
│   │   ├── mqc_fastqc_overrepresented_sequences_plot-2_1.svg
│   │   ├── mqc_fastqc_per_base_n_content_plot_1.svg
│   │   ├── mqc_fastqc_per_base_n_content_plot-2_1.svg
│   │   ├── mqc_fastqc_per_base_sequence_quality_plot_1.svg
│   │   ├── mqc_fastqc_per_base_sequence_quality_plot-2_1.svg
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Counts.svg
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot-2_Percentages.svg
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Counts.svg
│   │   ├── mqc_fastqc_per_sequence_gc_content_plot_Percentages.svg
│   │   ├── mqc_fastqc_per_sequence_quality_scores_plot_1.svg
│   │   ├── mqc_fastqc_per_sequence_quality_scores_plot-2_1.svg
│   │   ├── mqc_fastqc_sequence_counts_plot_1_pc.svg
│   │   ├── mqc_fastqc_sequence_counts_plot_1.svg
│   │   ├── mqc_fastqc_sequence_counts_plot-2_1_pc.svg
│   │   ├── mqc_fastqc_sequence_counts_plot-2_1.svg
│   │   ├── mqc_fastqc_sequence_duplication_levels_plot_1.svg
│   │   ├── mqc_fastqc_sequence_duplication_levels_plot-2_1.svg
│   │   ├── mqc_fastqc_sequence_length_distribution_plot_1.svg
│   │   ├── mqc_samtools_alignment_plot_1_pc.svg
│   │   ├── mqc_samtools_alignment_plot_1.svg
│   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Normalised_Counts.svg
│   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Observed_over_Expected_Counts.svg
│   │   ├── mqc_samtools-idxstats-mapped-reads-plot_Raw_Counts.svg
│   │   ├── mqc_star_alignment_plot_1_pc.svg
│   │   └── mqc_star_alignment_plot_1.svg
│   └── multiqc_report.html
├── pipeline_info
│   ├── execution_report_2025-06-20_09-00-09.html
│   ├── execution_timeline_2025-06-20_09-00-09.html
│   ├── execution_trace_2025-06-20_09-00-09.txt
│   ├── pipeline_dag_2025-06-20_09-00-09.html
│   └── software_versions.yml
├── samtools_flagstat
│   ├── <sample_name_1>\_sorted.bam.flagstat
│   ├── <sample_name_2>\_sorted.bam.flagstat
│   └── versions.yml
├── samtools_idxstats
│   ├── <sample_name_1>\_sorted.bam.idxstats
│   ├── <sample_name_2>\_sorted.bam.idxstats
│   └── versions.yml
├── samtools_index
│   ├── <sample_name_1>\_sorted.bam.bai
│   ├── <sample_name_2>\_sorted.bam.bai
│   └── versions.yml
├── samtools_sort
│   ├── <sample_name_1>\_sorted.bam
│   ├── <sample_name_2>\_sorted.bam
│   └── versions.yml
├── samtools_stats
│   ├── <sample_name_1>.stats
│   └── versions.yml
├── star_align
│   ├── <sample_name_1>.Aligned.sortedByCoord.out.bam
│   ├── <sample_name_1>.Log.final.out
│   ├── <sample_name_1>.Log.out
│   ├── <sample_name_1>.Log.progress.out
│   ├── <sample_name_1>.Signal.UniqueMultiple.str1.out.wig
│   ├── <sample_name_1>.Signal.UniqueMultiple.str2.out.wig
│   ├── <sample_name_1>.Signal.Unique.str1.out.wig
│   ├── <sample_name_1>.Signal.Unique.str2.out.wig
│   ├── <sample_name_1>.SJ.out.tab
│   ├── <sample_name_2>.Aligned.sortedByCoord.out.bam
│   ├── <sample_name_2>.Log.final.out
│   ├── <sample_name_2>.Log.out
│   ├── <sample_name_2>.Log.progress.out
│   ├── <sample_name_2>.Signal.UniqueMultiple.str1.out.wig
│   ├── <sample_name_2>.Signal.UniqueMultiple.str2.out.wig
│   ├── <sample_name_2>.Signal.Unique.str1.out.wig
│   ├── <sample_name_2>.Signal.Unique.str2.out.wig
│   ├── <sample_name_2>.SJ.out.tab
│   └── versions.yml
├── star_genomegenerate
│   ├── star
│   │   ├── chrLength.txt
│   │   ├── chrNameLength.txt
│   │   ├── chrName.txt
│   │   ├── chrStart.txt
│   │   ├── exonGeTrInfo.tab
│   │   ├── exonInfo.tab
│   │   ├── geneInfo.tab
│   │   ├── Genome
│   │   ├── genomeParameters.txt
│   │   ├── Log.out
│   │   ├── SA
│   │   ├── SAindex
│   │   ├── sjdbInfo.txt
│   │   ├── sjdbList.fromGTF.out.tab
│   │   ├── sjdbList.out.tab
│   │   └── transcriptInfo.tab
│   └── versions.yml
├── trimgalore
│   ├── <sample_name_1>\_1.fastq.gz_trimming_report.txt
│   ├── <sample_name_1>\_1_val_1_fastqc.html
│   ├── <sample_name_1>\_1_val_1_fastqc.zip
│   ├── <sample_name_1>\_1_val_1.fq.gz
│   ├── <sample_name_1>\_2.fastq.gz_trimming_report.txt
│   ├── <sample_name_1>\_2_val_2_fastqc.html
│   ├── <sample_name_1>\_2_val_2_fastqc.zip
│   ├── <sample_name_1>\_2_val_2.fq.gz
│   ├── <sample_name_2>\_1.fastq.gz_trimming_report.txt
│   ├── <sample_name_2>\_1_val_1_fastqc.html
│   ├── <sample_name_2>\_1_val_1_fastqc.zip
│   ├── <sample_name_2>\_1_val_1.fq.gz
│   ├── <sample_name_2>\_2.fastq.gz_trimming_report.txt
│   ├── <sample_name_2>\_2_val_2_fastqc.html
│   ├── <sample_name_2>\_2_val_2_fastqc.zip
│   ├── <sample_name_2>\_2_val_2.fq.gz
│   └── versions.yml
└── txdb
    ├── annotation_from_gtf.sqlite
    └── versions.yml
```

#### Outputs from mapping

`cat_fastq` folder with the input fastq files, merged by sample in case they were separated into different lanes.
`fastqc` folder with the results of the intitial quality check (before trimming or filtering). Currently it is not included in the MultiQC report.
`cutadapt` folder with the output from trimming the 5' G.
`trimgalore` folder with the output of `TrimGalore!` including adapter trimming and `FastQC` report (this one is included in the `MultiQC` report).
`star_genomegenerate` folder with the outpue of the `STAR genomegenerate` mode which creates the genome indeces.
`chrom_sizes_and_fai` folder with the genome index and chromosome sizes.
`star_align` folder with the output of `STAR` aligner: bam files, wig files of uniquely mapped and multi-mapped (the `unique_only` parameter defines whether the uniqely mapped wigs or the multi-mapped wigs are used downstream), tab file, and logs.
`bigwig` folder with the mapped reads in bigwig format.
`samtools_sort` folder with the sorted bam files.
`samtools_index` folder with the indexed bam files.
`samtools_stats` folder with the outputs from the `stat` command of `samtools` run after mapping.
`samtools_flagstat` folder with the outputs from the `flagstat` command of `samtools` run after mapping.
`samtools_idxstats` folder with the outputs from the `idxstat` command of `samtools` run after mapping.
`multiqc` folder with the data and plots, and the report of the mapping summary.
`pipeline_info` folder storing software versions and logs.

#### Outputs from CAGEr and CAGEfightR

`txdb` folder with the `sqlite` file of the TxDb file generated from the user provided `gtf` file.
`cager` folder with the `cager_report.html` file including the QC plots, with the respective user-provided parameters and descriptions. If the final set of called enhancers is empty, the corresponding plots shown in the report are replaced with placeholders saying "No enhancers found".
The folder also includes multiple subfolders as listed below with the intermediate files, tables, tracks, and plots in pdf format.

- `cager/intermediate_cagerobj` folder stores 5 different `RDS` files.
  - `initial_cagexp.rds` stores the data right after reading in of the mapped bigwig/bam files
  - `annotated_cagexp.rds` stores the data after it has been annotated.
  - `normalized_clustered_cagexp.rds` stores the data after it has been normalized, tag clusters, and consensus clusters called.
  - `supported_enhancers.rds` is the intermediate output of the `CAGEfightR` enhancer calling script. This inlcudes all enhancers that are called with support from the user defined number of samples.
  - `nonTSS_enhancers.rds` is the final output of the enhancer calling script. It is different from the `supported_enhancers.rds` as the `nonTSS_enhancers.rds` lists the enhancers that are not overlapping any of the consensus clusters identified by `CAGEr`.
- `cager/plots` folder stores the different plots and `RDS` files for the report. It also includes the TSS logos saved in the `<sample_name>_tagcluster_dominantTSSlogos_plot.pdf` file. Note: when reading in plots from RDS it is a good idea to import magrittr first, otherwise the plot content text is written out instead of the actual plot.
- `cager/tables` folder stores 3 `csv` files.
  - `consensus_clusters_tpm.csv` file stores the dataframe which is directly exported from CAGEr consensus clusters matching the scores provided in `consensusClustersTpm(ce)`. Rows are the consensus cluster regions and columns are the samples.
  - `consensus_cluster_per_sample_ctss.csv` files stores a dataframe that has the same structure as `consensus_clusters_tpm.csv` but instead of the scores defined by the overlapping TagCluster scores, `consensus_cluster_per_sample_ctss.csv` includes the scores caclulated by including all CTSS scores overlapping the consensus clusters. As tag clusters has already been filtered by a tpm threshold, the CTSS scores is higher or equal to the tag cluster scores. This is the preferred output for downstream analysis.
  - `enhancer_expression_per_sample.tsv` file stores a dataframe with the enhancer regions as rows and samples as columns. The values are tpm normalized CTSS scores.
- `cager/tracks` folder stores `bed` and `bigwig` files exported after identifying CTSS (raw strand specific bigwig), normalizing CTSS (normalized strand specific bigwig), tag clusters (bed), consensus clusters (bed), and enhancers (bed).

### FastQC

<details markdown="1">
<summary>Output files</summary>

- `fastqc/`
  - `*_fastqc.html`: FastQC report containing quality metrics.
  - `*_fastqc.zip`: Zip archive containing the FastQC report, tab-delimited data file and plot images.

</details>

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. It provides information about the quality score distribution across your reads, per base sequence content (%A/T/G/C), adapter contamination and overrepresented sequences. For further reading and documentation see the [FastQC help pages](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
