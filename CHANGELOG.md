# nf-core/cageseq: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - [2020-10-16]

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
