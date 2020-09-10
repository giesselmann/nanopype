# \BUILD\---------------------------------------------------------------
#
#  CONTENTS      : Nanopype build singularity
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
ARG TAG=latest
FROM nanopype/base_bionic:$TAG

# build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python-minimal python3-dev \
    wget rsync \
    git gcc g++ \
    binutils autoconf make cmake \
    libcunit1-dev libhdf5-dev libopenblas-dev \
    libzstd-dev \
    && rm -rf /var/lib/apt/lists/*

# update cmake for vbz_compression
RUN apt-get purge -y cmake
RUN git clone https://github.com/Kitware/CMake/ --branch v3.18.2 --depth 1 && cd CMake

RUN ./bootstrap && make -j 4 && make install && cd .. && rm -rf CMake
