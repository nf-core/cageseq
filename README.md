# nf-core/cageseq

**CAGE-seq pipeline**.

[![Build Status](https://travis-ci.com/nf-core/cageseq.svg?branch=master)](https://travis-ci.com/nf-core/cageseq)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/cageseq.svg)](https://hub.docker.com/r/nfcore/cageseq)

## Introduction
**UNDER DEVELOPMENT**

This pipeline is currenlty under development. The workflow is not yet finished.


**nf-core/cageseq** is a pipeline built for the analysis of CAGE-sequencing data.


Analysis steps consist of adapter and artefact trimming ([cuatadapt](https://cutadapt.readthedocs.io/en/stable/guide.html)), alignment to a reference ([STAR](https://github.com/alexdobin/STAR)) and CAGE tag counting.
Additionally, several quality control steps ([FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/), [MultiQC](https://multiqc.info/)) are included to allow for easy verification of results after a run.


The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker / singularity containers making installation trivial and results highly reproducible.


## Documentation
The nf-core/cageseq pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](docs/installation.md)
2. Pipeline configuration
    * [Local installation](docs/configuration/local.md)
    * [Adding your own system](docs/configuration/adding_your_own.md)
    * [Reference genomes](docs/configuration/reference_genomes.md)  
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)

<!-- TODO nf-core: Add a brief overview of what the pipeline does and how it works -->

## Credits
nf-core/cageseq was originally written by Kevin Menden.
