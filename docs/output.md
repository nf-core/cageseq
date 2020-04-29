# nf-core/cageseq: Output

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/)
and processes data using the following steps:

- [nf-core/cageseq: Output](#nf-corecageseq-output)
  - [Pipeline overview](#pipeline-overview)
  - [FastQC](#fastqc)
  - [cutadapt](#cutadapt)
  - [STAR](#star)
  - [RSeQC](#rseqc)
    - [Read distribution](#read-distribution)
  - [paraclu](#paraclu)
  - [MultiQC](#multiqc)

1.**Raw read QC**

  [FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your reads. It provides information about the quality score distribution across your reads, the per base sequence content (%T/A/G/C). You get information about adapter contamination and other overrepresented sequences.

  > **NB:** The FastQC plots displayed in the MultiQC report shows _untrimmed_ reads. They may contain adapter sequence and potentially regions with low quality. To see how your reads look after trimming, look at the FastQC reports in the `trim_galore` directory.

**Output directory: `results/fastqc`**

- `sample_fastqc.html`
  - FastQC report, containing quality metrics for your untrimmed raw fastq files
- `zips/sample_fastqc.zip`
  - zip file containing the FastQC report, tab-delimited data file and plot images

2.**Trimming**

[Cutadapt](https://cutadapt.readthedocs.io/en/stable/) finds and removes adapter
sequences, primers, poly-A tails and other types of unwanted sequence from your
high-throughput sequencing reads.

By default this pipeline trims the cut enzyme binding site at the 5'-end and
linkers at the 3'-end (can be disabled by setting `--trim_ecop` or `--trim_linkers to false`).
Furthermore, to combat the leading-G-bias of CAGE-seq, G's at the 5'-end are removed. Additional artifacts can be removed via the `--trim_artifacts` parameter.

All the following trimming process are skipped if `--skip_trimming` is set to true.

**Output directory: `results/trimmed`**

- `adapter_trimmed/sample.adapter_trimmed.fastq.gz`
  - Trimmed FastQ data
  - **NB:** Only saved if `--save_trimmed` has been specified.
- `adapter_trimmed/logs/`: Trimming report (describes which parameters that were used)
- if `--trim_5g`:
  - `g_trimmed/sample.g_trimmed.fastq.gz`
    - 5' G-corrected FastQ data
    - **NB:** Only saved if `--save_trimmed` has been specified.
  - `g_trimmed/logs/`: Trimming report (describes which parameters that were used)
- if `--trim_artifacts`:
  - `artifacts_trimmed/sample.artifact_trimmed.fastq.gz`
    - FastQ data after artifact removal
    - **NB:** Only saved if `--save_trimmed` has been specified.
  - `artifacts_trimmed/logs/`: Trimming report (describes which parameters that were used)

3.**Alignment**

The reads are aligned either with STAR or with bowtie.

### STAR

*Documentation*:
STAR is a read aligner designed for RNA sequencing. STAR stands for Spliced Transcripts Alignment to a Reference.

The STAR section of the MultiQC report shows a bar plot with alignment rates: good samples should have most reads as _Uniquely mapped_ and few _Unmapped_ reads.

### bowtie

![STAR](images/star_alignment_plot.png)

**Output directory: `results/STAR`**

- `Sample_Aligned.sortedByCoord.out.bam`
  - The aligned BAM file
- `Sample_Log.final.out`
  - The STAR alignment report, contains mapping results summary
- `Sample_Log.out` and `Sample_Log.progress.out`
  - STAR log files, containing a lot of detailed information about the run. Typically only useful for debugging purposes.
- `Sample_SJ.out.tab`
  - Filtered splice junctions detected in the mapping

4.**CTSS Clustering**

## paraclu

[paraclu](http://cbrc3.cbrc.jp/~martin/paraclu/) finds clusters in data
attached to sequences. It is used to define clusters of cage defined
transcription start sites (CTSS).

**Output directory: `results/ctss/clusters`**

## QC

### RSeQC

RSeQC is a package of scripts designed to evaluate the quality of RNA seq data. You can find out more about the package at the [RSeQC website](http://rseqc.sourceforge.net/).

This pipeline only runs the read destribution RSeQC scripts on the CTSS clusters. The results are summarised within the MultiQC report.

**Output directory: `results/rseqc`**

#### Read distribution

**Output: `Sample_read_distribution.txt`**

This tool calculates how mapped reads are distributed over genomic features.

![Read distribution](images/rseqc_read_distribution_plot.png)

RSeQC documentation: [read_distribution.py](http://rseqc.sourceforge.net/#read-distribution-py)

### MultiQC

[MultiQC](http://multiqc.info) is a visualisation tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in within the report data directory.

The pipeline has special steps which allow the software versions used to be reported in the MultiQC output for future traceability.

**Output directory: `results/multiqc`**

- `Project_multiqc_report.html`
  - MultiQC report - a standalone HTML file that can be viewed in your web browser
- `Project_multiqc_data/`
  - Directory containing parsed statistics from the different tools used in the pipeline

For more information about how to use MultiQC reports, see [http://multiqc.info](http://multiqc.info)
