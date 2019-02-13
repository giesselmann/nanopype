# Nanopype Dockerfile Basecalling
# BUILD STAGE
FROM ubuntu:16.04

MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

RUN apt-get --yes update && \
apt-get install -y --no-install-recommends wget \
    ca-certificates

RUN update-ca-certificates

RUN wget https://mirror.oxfordnanoportal.com/software/analysis/ont-guppy-cpu_2.3.1_linux64.tar.gz
RUN tar -xzkf ont-guppy-cpu_2.3.1_linux64.tar.gz -C / --strip 1
RUN rm ont-guppy-cpu_2.3.1_linux64.tar.gz

WORKDIR /
