# Nanopype Dockerfile
# BUILD STAGE
FROM ubuntu:16.04 as build_stage

MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## system packages
RUN apt-get --yes update
RUN apt-get --yes install wget
RUN apt-get --yes install git
RUN apt-get --yes install gcc g++
RUN apt-get --yes install binutils
RUN apt-get --yes install autoconf
RUN apt-get --yes install make cmake
RUN apt-get --yes install zlib1g-dev bzip2 libbz2-dev
RUN apt-get --yes install liblzma-dev libncurses5-dev
RUN apt-get --yes install python python3.5

## set up python 3
RUN ln -s /usr/bin/python3.5 /usr/bin/python3
RUN mkdir -p /src
WORKDIR /src
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py

## set up tools for nanopype
RUN git clone https://github.com/arq5x/bedtools2
RUN cd bedtools2 && make

RUN git clone https://github.com/samtools/htslib
RUN cd htslib && autoheader && autoconf && ./configure && make && make install

RUN git clone https://github.com/samtools/samtools
RUN cd samtools && autoheader && autoconf -Wno-syntax && ./configure && make && make install

RUN git clone https://github.com/lh3/minimap2
RUN cd minimap2 && make

RUN git clone https://github.com/isovic/graphmap
RUN cd graphmap && make modules && make

RUN git clone https://github.com/philres/ngmlr
RUN mkdir -p ngmlr/build && cd ngmlr/build && cmake .. && make

RUN git clone --recursive https://github.com/jts/nanopolish
RUN cd nanopolish && make

RUN git clone https://github.com/fritzsedlazeck/Sniffles
RUN mkdir -p Sniffles/build && cd Sniffles/build && cmake .. && make

# copy and configure nanopype
RUN mkdir -p /app
WORKDIR /app
COPY . /app/
RUN pip3 install -r requirements.txt

# PACKAGE STAGE
FROM ubuntu:16.04
RUN apt-get --yes update && \
apt-get install -y --no-install-recommends wget gcc g++ \
	zlib1g-dev bzip2 libbz2-dev \
	liblzma-dev libncurses5-dev \
	ca-certificates \
	python python3.5

RUN update-ca-certificates
RUN ln -s /usr/bin/python3.5 /usr/bin/python3
RUN mkdir -p /src
WORKDIR /src
RUN wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py

## copy binaries from build stage
RUN mkdir -p /bin
COPY --from=build_stage /src/bedtools2/bin/* /bin/
COPY --from=build_stage /src/samtools/samtools /bin/
COPY --from=build_stage /src/minimap2/minimap2 /bin/
COPY --from=build_stage /src/graphmap/bin/Linux-x64/graphmap /bin/
COPY --from=build_stage /src/ngmlr/bin/*/ngmlr /bin/
COPY --from=build_stage /src/nanopolish/nanopolish /bin/
COPY --from=build_stage /src/Sniffles/bin/*/sniffles /bin/

WORKDIR /bin
RUN wget ftp://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig 

## set up nanopye
RUN mkdir -p /app
WORKDIR /app
COPY . /app/
