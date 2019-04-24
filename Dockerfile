FROM nfcore/base
LABEL authors="Kevin Menden" \
      description="Docker image containing all requirements for nf-core/cageseq pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-cageseq-1.0dev/bin:$PATH

RUN apt-get update; apt-get install -y build-essential g++
RUN wget https://davetang.org/file/paraclu-9.zip
RUN unzip paraclu-9.zip; cd paraclu-9; make
ENV PATH /paraclu-9:$PATH

RUN wget https://sourceforge.net/projects/tagdust/files/tagdust-2.33.tar.gz
RUN tar -xvzf tagdust-2.33.tar.gz; cd tagdust-2.33; ./configure
#RUN make; make check; make install
RUN rm -rf tagdust-2.33.tar.gz
