FROM nfcore/base:1.8
LABEL authors="Kevin Menden; Tristan Kast" \
      description="Docker image containing all requirements for nf-core/cageseq pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
RUN conda env export --name nf-core-cageseq-1.0dev > nf-core-cageseq-1.0dev.yml
ENV PATH /opt/conda/envs/nf-core-cageseq-1.0dev/bin:$PATH

RUN apt-get update; apt-get install -y build-essential g++
RUN wget http://cbrc3.cbrc.jp/~martin/paraclu/paraclu-9.zip
RUN unzip paraclu-9.zip; cd paraclu-9; make
ENV PATH /paraclu-9:$PATH
