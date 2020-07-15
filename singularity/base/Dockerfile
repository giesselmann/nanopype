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
# Copyright (c) 2018-2020, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
FROM alpine:latest as build

# dependencies
RUN apk --update add --no-cache bash wget python3 py3-pip \
    hdf5-dev \
    zlib-dev bzip2 bzip2-dev \
    xz-libs xz-dev ncurses5-libs ncurses-dev \
    openblas-dev cunit-dev krb5-libs libidn \
    argp-standalone

# build dependencies
RUN apk add --no-cache --virtual .build-deps gcc g++ gfortran \
    python3-dev \
    musl-dev

## copy and configure nanopype
RUN mkdir -p /app
COPY . /app/
WORKDIR /app
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install setuptools wheel && \
    python3 -m pip install -r singularity/requirements.txt

# remove build dependencies
RUN apk del .build-deps


# Squash into flat image
FROM alpine:latest
COPY --from=build / /
