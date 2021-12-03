# \BUILD\---------------------------------------------------------------
#
#  CONTENTS      : Nanopype singularity demux
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
# BUILD STAGE
ARG TAG=latest
FROM build_focal:$TAG as build_stage

ENV LANG "en_US.utf8"
ENV LC_CTYPE "en_US.UTF-8"

## run setup rules
RUN mkdir /build
WORKDIR /app
# COPY . /app/
RUN snakemake --snakefile rules/install.smk --directory /build demux


# PACKAGE STAGE
FROM base_focal:$TAG
MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## packages
COPY --from=build_stage /build/bin/* /usr/bin/
COPY --from=build_stage /build/lib/* /usr/lib/
COPY --from=build_stage /usr/local/lib/python3.8/dist-packages /usr/local/lib/python3.8/dist-packages

WORKDIR /app
# default entrypoint is /bin/sh
