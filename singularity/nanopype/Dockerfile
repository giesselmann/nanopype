# \BUILD\---------------------------------------------------------------
#
#  CONTENTS      : Nanopype all-in-one singularity
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
# MODULE STAGES
ARG TAG=latest
FROM nanopype/basecalling:$TAG as basecalling
FROM nanopype/alignment:$TAG as alignment
FROM nanopype/methylation:$TAG as methylation
FROM nanopype/sv:$TAG as sv
FROM nanopype/transcript:$TAG as transcript
FROM nanopype/assembly:$TAG as assembly
#FROM nanopype/demux:$TAG as demux


# PACKAGE STAGE
FROM base_focal:$TAG
MAINTAINER Pay Giesselmann <giesselmann@molgen.mpg.de>

## packages
RUN mkdir -p /usr/data
COPY --from=basecalling /usr/bin/* /usr/bin/
COPY --from=basecalling /usr/lib/* /usr/lib/
COPY --from=basecalling /usr/data/* /usr/data/

COPY --from=alignment /usr/bin/* /usr/bin/

COPY --from=methylation /usr/bin/* /usr/bin/

COPY --from=sv /usr/bin/* /usr/bin/
COPY --from=sv /usr/lib/* /usr/lib/
COPY --from=sv /usr/local/lib/python3.6/dist-packages/ /usr/local/lib/python3.6/dist-packages/

COPY --from=transcript /usr/bin/* /usr/bin/
COPY --from=transcript /usr/local/lib/python3.6/dist-packages/ /usr/local/lib/python3.6/dist-packages/

COPY --from=assembly /usr/bin/* /usr/bin/
COPY --from=assembly /usr/local/lib/python3.6/dist-packages/ /usr/local/lib/python3.6/dist-packages/

#COPY --from=demux /usr/bin/* /usr/bin/
#COPY --from=demux /usr/local/lib/python3.6/dist-packages/ /usr/local/lib/python3.6/dist-packages/

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN git config --global user.email "nanopype"
RUN git config --global user.name "nanopype"

WORKDIR /app
COPY . /app
RUN pip install -r requirements.txt

# default entrypoint is /bin/sh
