# ![nf-core/cageseq](docs/images/nf-core-cageseq_logo.png)

**CAGE-seq pipeline**.

[![GitHub Actions CI Status](https://github.com/nf-core/cageseq/workflows/nf-core%20CI/badge.svg)](https://github.com/nf-core/cageseq/actions)
[![GitHub Actions Linting Status](https://github.com/nf-core/cageseq/workflows/nf-core%20linting/badge.svg)](https://github.com/nf-core/cageseq/actions)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A520.04.0-brightgreen.svg)](https://www.nextflow.io/)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.4095105.svg)](https://doi.org/10.5281/zenodo.4095105)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](https://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/cageseq.svg)](https://hub.docker.com/r/nfcore/cageseq)
[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23cageseq-4A154B?logo=slack)](https://nfcore.slack.com/channels/cageseq)

## Introduction

**nf-core/cageseq** is a bioinformatics analysis pipeline used for CAGE-seq sequencing data.

The pipeline takes raw demultiplexed fastq-files as input and includes steps for linker and artefact trimming
([cutadapt](https://cutadapt.readthedocs.io/en/stable/guide.html)), rRNA removal ([SortMeRNA](https://github.com/biocore/sortmerna), alignment to a reference genome ([STAR](https://github.com/alexdobin/STAR) or [bowtie1](http://bowtie-bio.sourceforge.net/index.shtml)) and CAGE tag counting
and clustering ([paraclu](http://cbrc3.cbrc.jp/~martin/paraclu/)).
Additionally, several quality control steps
([FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/),
[RSeQC](http://rseqc.sourceforge.net/),
[MultiQC](https://multiqc.info/))
are included to allow for easy verification of the results after a run.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

## Quick Start

1. Install [`nextflow`](https://nf-co.re/usage/installation)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) or [`Podman`](https://podman.io/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```bash
    nextflow run nf-core/cageseq -profile test,<docker/singularity/podman/conda/institute>
    ```

    > Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.

4. Start running your own analysis!

```bash
nextflow run nf-core/cageseq -profile <docker/singularity/podman/conda/institute> --input '*_R1.fastq.gz' --aligner <'star'/'bowtie1'> --genome GRCh38
```

See [usage docs](https://nf-co.re/cageseq/usage) for all of the available options when running the pipeline.

## Pipeline Summary

By default, the pipeline currently performs the following:

1. Input read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Adapter + EcoP15 + 5'G trimming ([`cutadapt`](https://github.com/OpenGene/fastp))
3. (optional) rRNA filtering ([`SortMeRNA`](https://github.com/biocore/sortmerna)),
4. Trimmed and filtered read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
5. Read alignment to a reference genome ([`STAR`](https://github.com/alexdobin/STAR) or [`bowtie1`](http://bowtie-bio.sourceforge.net/index.shtml))
6. CAGE tag counting and clustering ([`paraclu`](http://cbrc3.cbrc.jp/~martin/paraclu/))
7. CAGE tag clustering QC ([`RSeQC`](http://rseqc.sourceforge.net/))
8. Present QC and visualisation for raw read, alignment and clustering results ([`MultiQC`](http://multiqc.info/))


## Documentation

The nf-core/cageseq pipeline comes with documentation about the pipeline: [usage](https://nf-co.re/cageseq/usage) and [output](https://nf-co.re/cageseq/output).

## Credits

nf-core/cageseq was originally written by Kevin Menden ([@KevinMenden](https://github.com/KevinMenden)) and Tristan Kast ([@TrisKast](https://github.com/TrisKast)) and updated by Matthias Hörtenhuber ([@mashehu](https://github.com/mashehu)).

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#cageseq` channel](https://nfcore.slack.com/channels/cageseq) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use  nf-core/cageseq for your analysis, please cite it using the following doi: [10.5281/zenodo.4095105](https://doi.org/10.5281/zenodo.4095105)

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
> ReadCube: [Full Access Link](https://rdcu.be/b1GjZ)

In addition, references of tools and data used in this pipeline are as follows:

## [Nextflow](https://pubmed.ncbi.nlm.nih.gov/28398311/)

> Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables reproducible computational workflows. Nat Biotechnol. 2017 Apr 11;35(4):316-319. doi: 10.1038/nbt.3820. PubMed PMID: 28398311.

## Pipeline tools

* [BEDTools](https://pubmed.ncbi.nlm.nih.gov/20110278/)
  > Quinlan AR, Hall IM. BEDTools: a flexible suite of utilities for comparing genomic features. Bioinformatics. 2010 Mar 15;26(6):841-2. doi: 10.1093/bioinformatics/btq033. Epub 2010 Jan 28. PubMed PMID: 20110278; PubMed Central PMCID: PMC2832824.

* [bowtie](https://pubmed.ncbi.nlm.nih.gov/19261174/)
  > Langmead B, Trapnell C, Pop M, Salzberg SL. Ultrafast and memory-efficient alignment of short DNA sequences to the human genome. Genome Biol. 2009;10(3):R25. doi: 10.1186/gb-2009-10-3-r25. Epub 2009 Mar 4. PMID: 19261174; PMCID: PMC2690996.

* [cutadapt](http://journal.embnet.org/index.php/embnetjournal/article/view/200)
  > Martin, M., 2011. Cutadapt removes adapter sequences from high-throughput sequencing reads. EMBnet. journal, 17(1), pp.10-12.
  
* [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)

* [MultiQC](https://pubmed.ncbi.nlm.nih.gov/27312411/)
  > Ewels P, Magnusson M, Lundin S, Käller M. MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics. 2016 Oct 1;32(19):3047-8. doi: 10.1093/bioinformatics/btw354. Epub 2016 Jun 16. PubMed PMID: 27312411; PubMed Central PMCID: PMC5039924.

* [paraclu](https://pubmed.ncbi.nlm.nih.gov/18032727/)
  > Frith MC, Valen E, Krogh A, Hayashizaki Y, Carninci P, Sandelin A. A code for transcription initiation in mammalian genomes. Genome Res. 2008 Jan;18(1):1-12. doi: 10.1101/gr.6831208. Epub 2007 Nov 21. PMID: 18032727; PMCID: PMC2134772.

* [RSeQC](https://pubmed.ncbi.nlm.nih.gov/22743226/)
  > Wang L, Wang S, Li W. RSeQC: quality control of RNA-seq experiments Bioinformatics. 2012 Aug 15;28(16):2184-5. doi: 10.1093/bioinformatics/bts356. Epub 2012 Jun 27. PubMed PMID: 22743226.

* [SAMtools](https://pubmed.ncbi.nlm.nih.gov/19505943/)
  > Li H, Handsaker B, Wysoker A, Fennell T, Ruan J, Homer N, Marth G, Abecasis G, Durbin R; 1000 Genome Project Data Processing Subgroup. The Sequence Alignment/Map format and SAMtools. Bioinformatics. 2009 Aug 15;25(16):2078-9. doi: 10.1093/bioinformatics/btp352. Epub 2009 Jun 8. PubMed PMID: 19505943; PubMed Central PMCID: PMC2723002.

* [SortMeRNA](https://pubmed.ncbi.nlm.nih.gov/23071270/)
  > Kopylova E, Noé L, Touzet H. SortMeRNA: fast and accurate filtering of ribosomal RNAs in metatranscriptomic data Bioinformatics. 2012 Dec 15;28(24):3211-7. doi: 10.1093/bioinformatics/bts611. Epub 2012 Oct 15. PubMed PMID: 23071270.

* [STAR](https://pubmed.ncbi.nlm.nih.gov/23104886/)
  > Dobin A, Davis CA, Schlesinger F, Drenkow J, Zaleski C, Jha S, Batut P, Chaisson M, Gingeras TR. STAR: ultrafast universal RNA-seq aligner Bioinformatics. 2013 Jan 1;29(1):15-21. doi: 10.1093/bioinformatics/bts635. Epub 2012 Oct 25. PubMed PMID: 23104886; PubMed Central PMCID: PMC3530905.

* [UCSC tools](https://pubmed.ncbi.nlm.nih.gov/20639541/)
  > Kent WJ, Zweig AS, Barber G, Hinrichs AS, Karolchik D. BigWig and BigBed: enabling browsing of large distributed datasets. Bioinformatics. 2010 Sep 1;26(17):2204-7. doi: 10.1093/bioinformatics/btq351. Epub 2010 Jul 17. PubMed PMID: 20639541; PubMed Central PMCID: PMC2922891.

## Software packaging/containerisation tools

* [Anaconda](https://anaconda.com)
  > Anaconda Software Distribution. Computer software. Vers. 2-2.4.0. Anaconda, Nov. 2016. Web.

* [Bioconda](https://pubmed.ncbi.nlm.nih.gov/29967506/)
  > Grüning B, Dale R, Sjödin A, Chapman BA, Rowe J, Tomkins-Tinch CH, Valieris R, Köster J; Bioconda Team. Bioconda: sustainable and comprehensive software distribution for the life sciences. Nat Methods. 2018 Jul;15(7):475-476. doi: 10.1038/s41592-018-0046-7. PubMed PMID: 29967506.

* [BioContainers](https://pubmed.ncbi.nlm.nih.gov/28379341/)
  > da Veiga Leprevost F, Grüning B, Aflitos SA, Röst HL, Uszkoreit J, Barsnes H, Vaudel M, Moreno P, Gatto L, Weber J, Bai M, Jimenez RC, Sachsenberg T, Pfeuffer J, Alvarez RV, Griss J, Nesvizhskii AI, Perez-Riverol Y. BioContainers: an open-source and community-driven framework for software standardization. Bioinformatics. 2017 Aug 15;33(16):2580-2582. doi: 10.1093/bioinformatics/btx192. PubMed PMID: 28379341; PubMed Central PMCID: PMC5870671.

* [Docker](https://dl.acm.org/doi/10.5555/2600239.2600241)

* [Singularity](https://pubmed.ncbi.nlm.nih.gov/28494014/)
  > Kurtzer GM, Sochat V, Bauer MW. Singularity: Scientific containers for mobility of compute. PLoS One. 2017 May 11;12(5):e0177459. doi: 10.1371/journal.pone.0177459. eCollection 2017. PubMed PMID: 28494014; PubMed Central PMCID: PMC5426675.
