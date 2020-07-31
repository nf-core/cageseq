FROM nfcore/base:1.10.1
LABEL authors="Kevin Menden, Tristan Kast, Matthias Hörtenhuber" \
      description="Docker image containing all software requirements for the nf-core/cageseq pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create --quiet -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nf-core-cageseq-1.0dev/bin:$PATH
# Dump the details of the installed packages to a file for posterity
RUN conda env export --name nf-core-cageseq-1.0dev > nf-core-cageseq-1.0dev.yml
# Setup paraclu
RUN apt-get update; apt-get install -y build-essential g++
RUN wget http://cbrc3.cbrc.jp/~martin/paraclu/paraclu-9.zip && \
    unzip paraclu-9.zip; cd paraclu-9; make
ENV PATH /paraclu-9:$PATH

# Instruct R processes to use these empty files instead of clashing with a local version
RUN touch .Rprofile
RUN touch .Renviron
