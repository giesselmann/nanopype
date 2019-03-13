# \BUILD\---------------------------------------------------------------
#
#  CONTENTS      : Nanopype analysis singularity
#
#  DESCRIPTION   : Dockerfile
#
#  RESTRICTIONS  : none
#
#  REQUIRES      : none
#
# -----------------------------------------------------------------------
# Copyright (c) 2018-2019, Pay Giesselmann, Max Planck Institute for Molecular Genetics
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Written by Pay Giesselmann
# ---------------------------------------------------------------------------------
# Nanopype Dockerfile Analysis

# PACKAGE STAGE
FROM ubuntu:16.04
MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## packages
RUN apt-get --yes update && \
    apt-get install -y --no-install-recommends wget locales \
    ca-certificates apt-transport-https software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN update-ca-certificates
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# install R
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository 'deb [arch=amd64,i386] https://cran.rstudio.com/bin/linux/ubuntu xenial/'
RUN add-apt-repository -y ppa:jonathonf/texlive
RUN apt-get update && apt-get install --no-install-recommends --yes \
    g++ gcc make \
    r-base \
    pandoc \
    texlive-full \
    && rm -rf /var/lib/apt/lists/*

# install R packages
RUN R -e "install.packages('rmarkdown', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN R -e "install.packages('ggplot2', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN R -e "install.packages('knitr', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN R -e "install.packages('grid', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN R -e "install.packages('gridExtra', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"

RUN mkdir -p /app
COPY . /app/

ENV HOME /root

WORKDIR /
# default entrypoint is /bin/sh
