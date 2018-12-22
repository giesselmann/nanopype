# Installation

*Important*: If you encounter any trouble within the installation, open an issue on [github](https://github.com/giesselmann/nanopype/issues) to make others aware of the problem or write an E-Mail to ```giesselmann[at]molgen.mpg.de```. There is nothing more annoying than software that does not work.

## Docker

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
## Python

Nanopype is basically a python package maintaining most of its dependencies by building required tools from source in a user accessible path. This way usually no root privileges are required for the installation. The Dockerfile in the nanopype repository summarizes the minimal set of system wide packages required to build and run the pipeline.

### Virtual Environment
We recommend to create a python virtual environment and install nanopype and its dependencies into it. At least python version 3.4 is required.

    python3 -m venv /path/to/your/environment
    cd /path/to/your/environment
    source bin/activate

The installation will create the following folder structure relative to a given prefix directory:

```sh
|--prefix/
   |--src
   |--bin
   |--lib
   |--share
```

Nanopype relies on latest snakemake features, please consider updating your snakemake from the bitbucket repository:

```
mkdir -p src && cd src
git clone https://bitbucket.org/snakemake/snakemake.git
cd snakemake
pip3 install . --upgrade
cd ..
```

Finally install nanopype from [github.com/giesselmann](https://github.com/giesselmann/nanopype/):

```
git clone https://github.com/giesselmann/nanopype
cd nanopype
pip3 install . --upgrade
cd ..
```
To deactivate a virtual python environment just type:

    deactivate

***

## Tools
Nanopype integrates a variety of different tools merged into processing pipelines for common use cases. If you don't use the docker image, you will need to install them separately and tell nanopype via the environment [configuration](configuration.md) where to find them.

We provide snakemake rules to download and build all dependencies. From within the nanopype repository run

    cd nanopype
    snakemake --snakefile rules/install.smk --directory ../.. all

to build and install all tools into **src**, **bin** and **lib** folders two layers above the current directory. To only build a subset or specific targets e.g. samtools you can use:

    # core functionality
    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] core
    # extended functionality
    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] extended
    # specific tool only
    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] samtools

The --directory argument of snakemake is used as installation prefix. By running snakemake with e.g. -j 4 multiple targets are build in parallel at the cost of interleaved output to the shell. To further accelerate the build you may try the following to build 8 tools (-j 8) with 8 threads each (threads_build=8) using the CMake generator Ninja:

    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] all -j 8 --config threads_build=8 build_generator=Ninja

You will need to append the **bin** directory to your PATH variable, modify the paths in the environment config or re-run the nanopype installation with

    pip3 install . --upgrade --install-option="--tools=$(pwd)../../bin"

to make nanopype aware of the installed tools. This will create a .pth file in your python3 installation, modifying the PATH on python start.

### Core
**Basecalling**

:   * Albacore (access restricted to ONT community, manual install required)
    * Guppy (access restricted to ONT community, manual install required)
    * Flappie *https://github.com/nanoporetech/flappie*

**Alignment**

:   * Minimap2 *https://github.com/lh3/minimap2*
    * Graphmap *https://github.com/isovic/graphmap*
    * Ngmlr *https://github.com/philres/ngmlr*

**Methylation detection**

:   * Nanopolish *https://github.com/jts/nanopolish*

**Miscellaneous**

:   * Samtools *https://github.com/samtools/samtools*
    * Bedtools *https://github.com/arq5x/bedtools2*
    * UCSCTools *http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/*
        * bedGraphToBigWig

### Extended
**Structural variation**

:   * Sniffles *https://github.com/fritzsedlazeck/Sniffles*

**Demultiplexing**

:   * Deepbinner *https://github.com/rrwick/Deepbinner*

### Manual Installations

The applications not available for automated installation require manual interaction. Please also refer to the above Docker instructions on how to save changes to your container.

Guppy:
```
tar -xzf ont-guppy-cpu_2.1.3_linux64.tar.gz -C [INSTALL_PREFIX] --strip 1
```

Albacore:
```
pip3 install ont_albacore-2.3.3-cp35-cp35m-manylinux1_x86_64.whl
```

### Tests

You may wish to test your installation by running:

    python3 test/test_install.py

The test will check all supported tools, if you do not plan to use parts of the pipeline, you can ignore partially failing tests. Building all dependencies can take a significant amount of time, currently ~60 min on a single core machine.

***

## Troubleshooting

**terminated by signal 4**
:   Nanopype is mostly compiling integrated tools from source. In heterogenous cluster environments this can lead to errors if the compilation takes place on a machine supporting modern vector instructions (SSE, AVX, etc.) but execution also uses less recent computers. The error message *terminated by signal 4* indicates an instruction in the software not supported by the underlying hardware. Please re-compile and install the tools from a machine with a common subset of vector instructions in this case.

**not a supported wheel on this platform**
:   Nanopype requires at least python3.4 (The Docker image uses python3.5). If you install additional packages (e.g. albacore) from python wheels, make sure the downloaded binary packages matches the local python version.
