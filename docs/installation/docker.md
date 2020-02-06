# Docker

The all-in-one Docker image of Nanopype contains all its dependencies and is build automatically on [dockerHub](https://hub.docker.com/r/giesselmann/nanopype). This is primarily meant for local usage and does currently not support Snakemake's cluster engine. The compressed docker image size is ~500 MB. From the Docker shell run:

    docker pull giesselmann/nanopype

The container is tagged with the pipeline version. To obtain a specific version run e.g.:

    docker pull giesselmann/nanopype:v0.7.0

Docker images can get access to the hosts file system with mounts of type *bind*. Test the container by mounting your current directory:

    docker run -it --mount type=bind,source=$(pwd),target=/host giesselmann/nanopype:v0.7.0

Inside of the container type

    ls -l /host

to see the files of the host system from where the container was started. Leave a running container with *exit*.

- - -

Changes made to the file system of the container are not persistent. For configuration purposes we need to clone the pipeline repository and map it later into the container. This requires a **git** and **python3** installation on the host system.

!!! warning "Pipeline version"
    When using the Docker installation you clone the pipeline twice, the container from DockerHub and the pipeline repository from GitHub. Make sure to use the same version in both cases, it is highly recommended to use a tagged and not the 'latest' version.

Adjust the version of the *git checkout* according to the one used with *docker pull* e.g.:

```
docker pull giesselmann/nanopype:v0.7.0
```

and

```
mkdir -p ~/src && cd ~/src
git clone --recursive https://github.com/giesselmann/nanopype
cd nanopype && git checkout v0.7.0
python3 -m pip install -r requirements.txt
```

To use Docker for processing you will need to mount the pipeline, your data and a processing directory to the container. Any processing results not copied to the host will not persist inside the container after leaving it! From the Nanopype repository run:
```
docker run -it --mount type=bind,source=$(pwd),target=/app \
--mount type=bind,source=/path/to/miniondata,target=/data/raw \
--mount type=bind,source=/path/to/project,target=/processing \
--user $(id -u):$(id -g) \
giesselmann/nanopype:v0.7.0
```

The *--user* argument reads user and group id from the current user. This is important since otherwise files created from inside the container are owned by **root**. The system in the container does not know about your outside user, the shell will therefore look like this:

```
I have no name!@df5f6d317225:/data/processing$
```
