# Nanopype Dockerfile Demultiplexing

# PACKAGE STAGE
FROM ubuntu:16.04
MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## packages
RUN apt-get --yes update && \
apt-get install -y --no-install-recommends wget locales \
    ca-certificates apt-transport-https software-properties-common

RUN update-ca-certificates
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# install R
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN add-apt-repository 'deb [arch=amd64,i386] https://cran.rstudio.com/bin/linux/ubuntu xenial/'
RUN apt-get update && apt-get install --no-install-recommends --yes \
    r-base \
    pandoc \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-fonts-recommended \
    && rm -rf /var/lib/apt/lists/*

ENV HOME /root

# install R packages
RUN Rscript -e "install.packages('rmarkdown', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN Rscript -e "install.packages('ggplot2', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN Rscript -e "install.packages('knitr', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN Rscript -e "install.packages('grid', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"
RUN Rscript -e "install.packages('gridExtra', repos = 'https://cloud.r-project.org/', lib='/usr/local/lib/R/site-library')"

RUN mkdir -p /app
COPY . /app/

WORKDIR /
# default entrypoint is /bin/sh
