# Nanopype Dockerfile

FROM ubuntu:16.04

# General dependencies
RUN apt-get --yes update

RUN apt-get --yes install wget
RUN apt-get --yes install git
RUN apt-get --yes install gcc
RUN apt-get --yes install binutils
RUN apt-get --yes install make
RUN apt-get --yes install cmake
RUN apt-get --yes install python3.5