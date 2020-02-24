FROM nfcore/base:1.9
LABEL authors="Kevin Menden; Tristan Kast" \
      description="Docker image containing all software requirements for the nf-core/cageseq pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nf-core-cageseq-1.0dev/bin:$PATH
# Dump the details of the installed packages to a file for posterity
RUN conda env export --name nf-core-cageseq-1.0dev > nf-core-cageseq-1.0dev.yml
RUN apt-get update; apt-get install -y build-essential g++
RUN wget http://cbrc3.cbrc.jp/~martin/paraclu/paraclu-9.zip && \
    unzip paraclu-9.zip; cd paraclu-9; make
ENV PATH /paraclu-9:$PATH
