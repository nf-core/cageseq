FROM nfcore/base:1.13.1
LABEL authors="Kevin Menden, Tristan Kast, Matthias Hörtenhuber" \
      description="Docker image containing all software requirements for the nf-core/cageseq pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create --quiet -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nf-core-cageseq-1.0.2/bin:$PATH

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name nf-core-cageseq-1.0.2 > nf-core-cageseq-1.0.2.yml
