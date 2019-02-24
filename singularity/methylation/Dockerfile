# Nanopype Dockerfile Methylation
# BUILD STAGE
FROM ubuntu:16.04 as build_stage

## system packages
RUN apt-get --yes update && apt-get install -y --no-install-recommends wget \
    git gcc g++ ninja-build ca-certificates \
    binutils autoconf make cmake zlib1g-dev bzip2 libbz2-dev \
    liblzma-dev libncurses5-dev \
    apt-transport-https \
    python python3.5 python3.5-dev

RUN update-ca-certificates

## set up python 3
RUN ln -s /usr/bin/python3.5 /usr/bin/python3
RUN mkdir -p /src
WORKDIR /src
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py

## copy and configure nanopype
RUN mkdir -p /app
COPY . /app/
WORKDIR /app
RUN pip3 install . --upgrade

## run setup rules
RUN mkdir /build
RUN snakemake --snakefile rules/install.smk --config build_generator=Ninja --directory /build methylation

# PACKAGE STAGE
FROM ubuntu:16.04
MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## packages
RUN apt-get --yes update && \
    apt-get install -y --no-install-recommends wget locales \
    gcc python3-dev \
    ca-certificates apt-transport-https \
    libcunit1 libhdf5-10 libopenblas-base \
    && rm -rf /var/lib/apt/lists/*

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
RUN python3 -m pip install -r requirements.txt

COPY --from=build_stage /build/bin/* /usr/bin/

WORKDIR /
# default entrypoint is /bin/sh
