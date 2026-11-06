# nf-core/cageseq: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0dev - [date]

Second release of nf-core/cageseq, created with the [nf-core](https://nf-co.re/) template.

### `Changed`

- The pipeline code complies with the strict Nextflow syntax (`nextflow lint` under
  Nextflow 26.10.5 reports no errors), so it runs on Nextflow 26.04 and later, whose
  parser rejects the old syntax. The changes do not alter what the pipeline produces:
  `script:` labels in local modules, `env('PWD')` for the implicit `PWD` variable,
  `def` for closure-local variables, `naturalKey` as a standalone function, `channel`
  instead of `Channel`, explicit closure parameters.
- The minimum Nextflow version is 25.10.4, the lowest version the pipeline was tested on.
- MultiQC plot export has a time limit of 300 s (`export_plots_timeout`). The default of 30 s lost
  plot files without failing the run in a scenario with 42 samples.
- The `singularity` profile sets `singularity.runOptions` and `singularity.envWhitelist`, which were
  never applied without the `singularity.` prefix: a task's `/tmp` is now `APPTAINER_TMPDIR` when that is
  set. The unapplied `cacheDir` option is removed, so `NXF_SINGULARITY_CACHEDIR` still decides the image cache.
- Stub mode (`-stub-run`) works for every process: the `SAMTOOLS_DEDUP` stub
  creates the files its script creates (`<prefix>.bam` and `<prefix>_dedup_stats.txt`), and the six
  CAGEr modules (`CAGER_READIN`, `CAGER_TAG_QC`, `CAGER_PROCESSING`, `CAGER_TAGCLUSTER_QC`,
  `CAGEFIGHTR_ENHANCER_CALLING`, `CAGER_REPORT`) have stub blocks. Stub blocks only; no script,
  input, output or config line changed.
- The vendored `star/align` module is patched (`modules/nf-core/star/align/star-align.diff`): its stub
  creates the four wig files that STAR writes with `--outWigType wiggle read1_5p`, which the STAR
  subworkflow indexes. With one wig file, every STAR run in stub mode stopped at `CAGER_READIN`. Stub
  block only; real runs do not change.
- `CAGER_READIN` reads the copies of the bigWig or BAM files staged into its task directory, as it already
  did in cageronly mode, instead of the published files by absolute path. It no longer depends on what
  is bound into the container or on publishing having finished. The `inputFiles` slot of the CAGEr
  objects of a full run now holds file names, not absolute published paths.
- The published `cager_sample_list.csv` is written with `launchDir.resolve(params.outdir)`, so its paths are
  right with an absolute `--outdir`, which previously made `CAGER_READIN` fail.
- `move` is no longer an allowed value of `--publish_dir_mode`. Outputs that later processes use must stay in
  the work directory, and Nextflow documents `move` only for terminal processes.

## v1.0dev - [date]

Initial release of nf-core/cageseq, created with the [nf-core](https://nf-co.re/) template.

### `Added`

### `Fixed`

### `Dependencies`

### `Deprecated`
