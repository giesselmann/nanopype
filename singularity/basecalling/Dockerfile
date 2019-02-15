# Nanopype Dockerfile Basecalling
# BUILD STAGE
FROM ubuntu:16.04 as build_stage

## system packages
RUN apt-get --yes update && apt-get install -y --no-install-recommends wget \
    git gcc g++ ninja-build ca-certificates \
    apt-transport-https \
    make cmake python3.5 python3.5-dev \
    libcunit1-dev libhdf5-dev libopenblas-dev

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
RUN snakemake --snakefile rules/install.smk --config build_generator=Ninja --directory /build Flappie --config flappie_src=False

# PACKAGE STAGE
FROM ubuntu:16.04
MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## packages
RUN apt-get --yes update && \
apt-get install -y --no-install-recommends wget \
    gcc python3-dev \
    ca-certificates lsb-release apt-transport-https \
    libcunit1 libhdf5-10 libopenblas-base

RUN update-ca-certificates

RUN wget -O- https://mirror.oxfordnanoportal.com/apt/ont-repo.pub | apt-key add - && \
    echo "deb http://mirror.oxfordnanoportal.com/apt xenial-stable non-free" | \
        tee /etc/apt/sources.list.d/nanoporetech.sources.list

## GUPPY
RUN apt-get --yes update && \
apt-get install -y ont-guppy-cpu=2.3.1-1~xenial

RUN mkdir -p /app
COPY . /app/
WORKDIR /app

RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py
RUN python3 -m pip install -r requirements.txt

COPY --from=build_stage /build/bin/* /bin/

WORKDIR /
# default entrypoint is /bin/sh
