# Source

Nanopype can be installed without root privileges as it's maintaining most of its dependencies by building required tools from source in a user accessible path. Currently the following list of system wide packages is required to build all included software packages (names on MacOS might be different):

* git wget
* gcc g++
* binutils autoconf make cmake
* zlib1g-dev bzip2 libbz2-dev
* liblzma-dev libncurses5-dev libcunit1-dev

These packages are likely present in most production environments. Please also refer to the Dockerfiles in the singularity folder of the pipeline repository. If you need only a subset of the provided tools the number of dependencies might decrease.

The following build process is the most flexible and customizable installation and might despite careful tests lead to errors on your specific system. Please do not hesitate to contact us and ask for help. Also check and open an issue where needed on [github](https://github.com/giesselmann/nanopype/issues).

Start with creating a virtual python environment:

```
python3 -m venv /path/to/your/environment
cd /path/to/your/environment
source bin/activate
```

Or using conda:

```
conda create -n nanopype python=3.4 anaconda
source activate nanopype

```

## Snakemake

Nanopype is based on the Snakemake pipeline engine. With python3.4 pip is already installed and you get Snakemake by executing:

```
pip3 install --upgrade snakemake
```

Alternatively you might use the conda package manager:

```
conda install -c bioconda -c conda-forge snakemake
```

Nanopype relies on latest Snakemake features, please consider updating your Snakemake from the bitbucket repository. From your home or project directory run:

```
mkdir -p src && cd src
git clone https://bitbucket.org/snakemake/snakemake.git
cd snakemake
pip3 install . --upgrade
cd ..
```

## Nanopype
Finally install Nanopype from [github.com/giesselmann](https://github.com/giesselmann/nanopype/). If you use conda you find pip in the *bin/* folder of the conda installation. If you use a conda virtual environment use the pip from the *envs/nanopype/bin*.

```
git clone --recursive https://github.com/giesselmann/nanopype
cd nanopype
pip3 install -r requirements.txt
cd ..
```

## Tools

The installation will create the following folder structure relative to a given [INSTALL_PREFIX] directory:

```sh
|--INSTALL_PREFIX/
   |--src
   |--bin
   |--lib
   |--share
```

Nanopype integrates a variety of different **[tools](../tools.md)** merged into processing pipelines for common use cases. We provide Snakemake rules to download and build all dependencies. From within the Nanopype repository run

    snakemake --snakefile rules/install.smk --directory /path/to/INSTALL_PREFIX all

to build and install all tools into **src**, **bin** and **lib** folders of the INSTALL_PREFIX directory. To only build a subset or specific targets e.g. samtools you can use:

    # core functionality of basecalling and alignment
    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] processing
    # extended analysis functionality
    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] analysis
    # specific tool only
    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] samtools

The --directory argument of Snakemake is used as installation prefix. By running Snakemake with e.g. -j 4 multiple targets are build in parallel at the cost of interleaved output to the shell. To further accelerate the build you may try the following to build 8 tools (-j 8) with 8 threads each (threads_build=8) using the CMake generator Ninja:

    snakemake --snakefile rules/install.smk --directory [INSTALL_PREFIX] all -j 8 --config threads_build=8 build_generator=Ninja

In case your **bin** directory is not listed in the PATH variable (echo $PATH), execute

    python3 scripts/setup_path.py /path/to/INSTALL_PREFIX/bin

to make Nanopype aware of the installed tools. This will create a .pth file in your python3 installation, modifying the PATH temporarily on python startup. Alternatively you can run the following line once or append it to your ~/.bashrc. Note that in cluster environments this is not necessarily changing the PATH on all nodes!

    export PATH=/path/to/INSTALL_PREFIX/bin:$PATH

To deactivate a virtual python environment after installation or usage of the pipeline just type:

```
deactivate
```

for plain and

```
source deactivate
```

for conda virtual environments.

Mission accomplished! Everything else is solved at run time by Snakemake and Nanopype.

!!! warning "Configuration"
    Do not forget to follow the [global](configuration.md) configuration once and for each sample the [local](../usage/general.md) one.


***

## Troubleshooting
There are some common errors that could arise during the installation process. If you encounter one of the following error messages, please consider the respective solution attempts.

**not a supported wheel on this platform**
:   Nanopype requires at least python3.4 (The Docker image uses python3.5). If you install additional packages (e.g. albacore) from python wheels, make sure the downloaded binary packages matches the local python version.

**terminated by signal 4**
:   Nanopype is mostly compiling integrated tools from source. In heterogeneous cluster environments this can lead to errors if the compilation takes place on a machine supporting modern vector instructions (SSE, AVX, etc.) but execution also uses less recent computers. The error message *terminated by signal 4* indicates an instruction in the software not supported by the underlying hardware. Please re-compile and install the tools from a machine with a common subset of vector instructions in this case.
