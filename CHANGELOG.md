# nf-core/cageseq: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0 Nickel Chicken - [2021-05-12]

This release marks the switch from DSL1 to DSL2 language. Major structural changes have therefore been made to the pipeline.

### Major changes

* Changed to general DSL2 structure with additional folders:
  * `lib` : groovy helper functions
  * `modules` : local and nf-core modules
  * `subworkflows` : small subworkflows
  * `workflows` : the main pipeline workflows
* parameter validation with groovy functions and the `nextflow_schema.json`
* deletion of `Dockerfile` and `environment.yml`

### Minor changes

* Update template to nf-core/tools `1.14`
* reads the `--input` parameters correclty
* cleaned up multiqc config

## v1.0.1 - [2020-11-23]

### `Added`

* Update template to nf-core/tools `1.12`

### `Fixed`

* clusters on the negative strand were not included in the final output file
* bigwig export needs sorted input

## v1.0.0 (Gold Lion) - [2020-10-16]

Initial release of nf-core/cageseq, created with the [nf-core](https://nf-co.re/) template.

### Pipeline summary

1. Input read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Adapter + EcoP15 + 5'G trimming ([`cutadapt`](https://github.com/OpenGene/fastp))
3. (optional) rRNA filtering ([`SortMeRNA`](https://github.com/biocore/sortmerna)),
4. Trimmed and filtered read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
5. Read alignment to a reference genome ([`STAR`](https://github.com/alexdobin/STAR) or [`bowtie1`](http://bowtie-bio.sourceforge.net/index.shtml))
6. CAGE tag counting and clustering ([`paraclu`](http://cbrc3.cbrc.jp/~martin/paraclu/))
7. CAGE tag clustering QC ([`RSeQC`](http://rseqc.sourceforge.net/))
8. Present QC and visualisation for raw read, alignment and clustering results ([`MultiQC`](http://multiqc.info/))
