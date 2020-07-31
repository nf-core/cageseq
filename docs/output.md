# nf-core/cageseq: Output

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/)
and processes data using the following steps:

<!-- /TOC -->

## 1. Raw read QC

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. It provides information about the quality score distribution across your reads, per base sequence content (%A/T/G/C), adapter contamination and overrepresented sequences.

For further reading and documentation see the [FastQC help pages](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

  > **NB:** The FastQC plots displayed in the MultiQC report shows _untrimmed_ reads. They may contain adapter sequence and potentially regions with low quality. To see how your reads look after trimming, look at the FastQC reports in the `trim_galore` directory.

* `fastqc/`
  * `*_fastqc.html`: FastQC report containing quality metrics for your untrimmed raw fastq files.
* `fastqc/zips/`
  * `*_fastqc.zip`: Zip archive containing the FastQC report, tab-delimited data file and plot images.


## 2. Trimming

[Cutadapt](https://cutadapt.readthedocs.io/en/stable/) finds and removes adapter
sequences, primers, poly-A tails and other types of unwanted sequence from your
high-throughput sequencing reads.

By default this pipeline trims the cut enzyme binding site at the 5'-end and
linkers at the 3'-end (can be disabled by setting `--trim_ecop` or `--trim_linkers to false`).
Furthermore, to combat the leading-G-bias of CAGE-seq, G's at the 5'-end are removed. Additional artifacts can be removed via the `--trim_artifacts` parameter.

All the following trimming process are skipped if `--skip_trimming` is set to true and the output below is only available if '--save_trimmed' is set to true.

**Output directory: `results/trimmed`**

- `adapter_trimmed/sample.adapter_trimmed.fastq.gz`
  - FastQ file after removal of linkers and EcoP15 site.
- `adapter_trimmed/logs/`
  - Trimming report (describes which parameters that were used)
- if `--trim_5g`:
  - `g_trimmed/sample.g_trimmed.fastq.gz`
    - 5' G-corrected FastQ file
  - `g_trimmed/logs/`
    - Trimming report (describes which parameters that were used)
- if `--trim_artifacts`:
  - `artifacts_trimmed/sample.artifact_trimmed.fastq.gz`
    - FastQ file after artifact removal
  - `artifacts_trimmed/logs/`
    - Trimming report (describes which parameters that were used)

## 3. Alignment

The reads are aligned either with STAR or with bowtie, set via `--aligner`.

### STAR

STAR is a read aligner designed for RNA sequencing. STAR stands for Spliced Transcripts Alignment to a Reference.

The STAR section of the MultiQC report shows a stacked bar plot with alignment rates:
good samples should have most reads as _Uniquely mapped_ and few _Unmapped_ reads.
![STAR](images/star_alignment_plot.png)

### Bowtie 1

[Bowtie 1](http://bowtie-bio.sourceforge.net/index.shtml) is an ultrafast,
memory-efficient short read aligner.

The bowtie 1 section of the MultiQC report shows a stacked bar plot with
alignment rates:
good samples should have most reads as _aligned_ and few _Not aligned_ reads.
![STAR](images/bowtie1_alignment_plot.png)

**Output directory: `results/STAR`**

- `Sample_Aligned.sortedByCoord.out.bam`
  - The aligned BAM file
- `Sample_Log.final.out`
  - The STAR alignment report, contains mapping results summary
- `Sample_Log.out` and `Sample_Log.progress.out`
  - STAR log files, containing a lot of detailed information about the run. Typically only useful for debugging purposes.
- `Sample_SJ.out.tab`
  - Filtered splice junctions detected in the mapping

## 5. CTSS generation

The custom script `bin/make_ctss.sh` generates a bed file for each sample with
unclustered cage defined transcription start sites (CTSS).

**Output directory: `results/ctss`**

- `Sample.ctss.bed`
  - A BED6 file with the cage defined transcription start sites

## 4. CTSS clustering

### paraclu

[paraclu](http://cbrc3.cbrc.jp/~martin/paraclu/) finds clusters in data
attached to sequences. It is applied on the pool of all ctss bed files to
cluster and returns a bed file with the clustered CTSSs.

**Output directory: `results/ctss/clusters`**

- `ctss_all_clustered_simplified.bed`
  - A BED6 file with the clustered CTSSs and their pooled counts

## 6. Count table generation

The ctss files are intersected with the clusteres identified by paraclu and
summarized in a count table.

**Output directory: `results/ctss/`**

- `count_table.tsv`:
  - Each column of the count table stands for one sample and each row for one tag cluster. The first row of this table is the header with sample names and the first column contains the tag cluster coordinates.

## 7. QC of results

### RSeQC

RSeQC is a package of scripts designed to evaluate the quality of RNA seq data. You can find out more about the package at the [RSeQC website](http://rseqc.sourceforge.net/).

This pipeline only runs the read destribution RSeQC scripts on the CTSS clusters. The results are summarised within the MultiQC report.

**Output directory: `results/rseqc`**

#### Read distribution

[read_distribution.py](http://rseqc.sourceforge.net/#read-distribution-py)
calculates how mapped reads are distributed over genomic features.

![Read distribution](images/rseqc_read_distribution_plot.png)
**Output: `Sample_read_distribution.txt`**

### MultiQC

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarizing all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability.

For more information about how to use MultiQC reports, see [https://multiqc.info](https://multiqc.info).

**Output files:**

* `multiqc/`
  * `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  * `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  * `multiqc_plots/`: directory containing static images from the report in various formats.

## Pipeline information

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.

* `pipeline_info/`
  * Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  * Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.csv`.
  * Documentation for interpretation of results in HTML format: `results_description.html`.
