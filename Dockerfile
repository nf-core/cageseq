FROM nfcore/base
LABEL authors="Kevin Menden" \
      description="Docker image containing all requirements for nf-core/cageseq pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-cageseq-1.0dev/bin:$PATH

RUN sudo apt-get update; sudo apt-get install build-essential g++
RUN wget https://davetang.org/file/paraclu-9.zip
RUN unzip paraclu-9.zip; cd paraclu-9; make
ENV PATH /paraclu-9:$PATH
