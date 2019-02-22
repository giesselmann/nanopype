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
RUN apt-get update
RUN apt-get install --yes r-base pandoc

# install R packages
RUN R -e "install.packages('rmarkdown', repos = 'https://cloud.r-project.org/')"
RUN R -e "install.packages('ggplot2', repos = 'https://cloud.r-project.org/')"
RUN R -e "install.packages('knitr', repos = 'https://cloud.r-project.org/')"
RUN R -e "install.packages('grid', repos = 'https://cloud.r-project.org/')"
RUN R -e "install.packages('gridExtra', repos = 'https://cloud.r-project.org/')"
RUN R -e "install.packages('tinytex')" -e "tinytex::install_tinytex()"

RUN mkdir -p /app
COPY . /app/
WORKDIR /app

WORKDIR /
# default entrypoint is /bin/sh
