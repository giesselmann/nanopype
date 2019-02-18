# Nanopype Dockerfile Demultiplexing

# PACKAGE STAGE
FROM ubuntu:16.04
MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## packages
RUN apt-get --yes update && \
apt-get install -y --no-install-recommends wget locales \
    git gcc g++ python3-dev \
    zlib1g-dev bzip2 libbz2-dev \
    ca-certificates apt-transport-https

RUN update-ca-certificates
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN mkdir -p /app
COPY . /app/
WORKDIR /app

RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py
RUN pip3 install . --upgrade

RUN snakemake --snakefile rules/install.smk --directory /usr deepbinner

WORKDIR /
# default entrypoint is /bin/sh
