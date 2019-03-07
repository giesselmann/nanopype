# Docker

The all-in-one Docker image of Nanopype contains all its dependencies and is build automatically on [dockerHub](https://hub.docker.com/r/giesselmann/nanopype). This is primarily meant for local usage and does currently not support snakemakes cluster engine. The compressed docker image size is ~500 MB. From the Docker shell run:

    docker pull giesselmann/nanopype

The container is tagged with the pipeline version. To obtain a specific version run e.g.:

    docker pull giesselmann/nanopype:v0.4.0

Docker images can get access to the hosts file system with the *bind* argument. Test the container by mounting your current directory:

    docker run -it --mount type=bind,source=$(pwd),target=/host giesselmann/nanopype

Inside of the container type

    ls -l /host

to see the files of the host system from where the container was started. Leave a running container with *exit*.

Changes made to the file system of the container are not persistent. For configuration purpose we clone the pipeline repository and map it later into the container.

```
mkdir -p src && cd src
git clone --recursive https://github.com/giesselmann/nanopype
cd nanopype
```

To use Docker for processing you will need to mount the pipeline, your data and a processing directory to the container. Any processing results not copied to the host will not persist inside the container after leaving it! From the Nanopype repository run:

    docker run -it --mount type=bind,source=$(pwd),target=/app \
    --mount type=bind,source=/path/to/miniondata,target=/data \
    --mount type=bind,source=/path/to/project,target=/processing giesselmann/nanopype
