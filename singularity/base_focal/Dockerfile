# \BUILD\---------------------------------------------------------------
#
#  CONTENTS      : Nanopype base singularity
#
#  DESCRIPTION   : Dockerfile
#
#  RESTRICTIONS  : none
#
#  REQUIRES      : none
#
# -----------------------------------------------------------------------
# Copyright (c) 2018-2021, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
FROM ubuntu:focal as build

# locales
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    ca-certificates \
    lsb-release \
    apt-transport-https \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && update-ca-certificates

RUN export LANG="en_US.utf8" && \
    export LC_CTYPE="en_US.UTF-8" && \
    export LANGUAGE="en_US.utf8" && \
    export LC_ALL="en_US.utf8"


# dependencies
RUN apt-get install -y --no-install-recommends \
    python3 python3-pip \
    libgomp1 \
    zlib1g-dev \
    libzstd-dev \
    libcurl4 \
    libfreetype6 \
    bzip2 libbz2-dev \
    liblzma-dev libncurses5-dev \
    libcunit1 libhdf5-103 libidn11 libopenblas-base \
    libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*


## copy and configure nanopype
RUN mkdir -p /app
COPY . /app/
WORKDIR /app
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install setuptools wheel && \
    python3 -m pip install -r singularity/requirements.txt


# Squash into flat image
FROM ubuntu:focal
COPY --from=build / /

RUN export LANG="en_US.utf8" && \
    export LC_CTYPE="en_US.UTF-8"
