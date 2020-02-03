#!/bin/sh
# basecalling
# docker build -t basecalling --shm-size 4g -f singularity/basecalling/Dockerfile .
# alignment
#docker build -t alignment --shm-size 4g -f singularity/alignment/Dockerfile .
# methylation
#docker build -t methylation --shm-size 4g -f singularity/methylation/Dockerfile .
# sv
#docker build -t sv --shm-size 4g -f singularity/sv/Dockerfile .
# transcript
#docker build -t transcript --shm-size 4g -f singularity/transcript/Dockerfile .
# demux
#docker build -t demux --shm-size 4g -f singularity/demux/Dockerfile .
# demux
docker build -t analysis --shm-size 4g -f singularity/analysis/Dockerfile .
