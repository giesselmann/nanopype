# Docker

* Make own subsection here containing more detailed description on what it means to include other tools and why (ONT software)
* Link to docker

Run nanopype with all its dependencies from within an automated built docker container. This is primarily for local usage and does currently not support snakemakes cluster engine. The compressed docker image size is ~500 MB.

    docker pull giesselmann/nanopype

You can extend and customize your docker in the following way:

    docker run -it --mount type=bind,source=/host/installer/path,target=/src giesselmann/nanopype

In the docker shell you could install e.g. albacore from ONT after you downloaded the python wheel to the hosts */host/installer/path*:

    pip3 install ont_albacore-2.3.3-cp35-cp35m-manylinux1_x86_64.whl

Press CTRL + P and CTRL + Q to detach from the running container and run

    docker ps

to get the *CONTAINER_ID* of the currently running container. Save the changes, attach to the running container and exit:

    docker commit CONTAINER_ID giesselmann/nanopype
    docker attach CONTAINER_ID

***

## Troubleshooting
There are some common errors that could arise during the installation process. If you encounter one of the following error messages, please consider the respective solution attempts.

**not a supported wheel on this platform**
:   Nanopype requires at least python3.4 (The Docker image uses python3.5). If you install additional packages (e.g. albacore) from python wheels, make sure the downloaded binary packages matches the local python version.
