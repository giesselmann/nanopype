# Singularity

In order to use the Singularity driven version of Nanopype a working python3 with Snakemake and the pipeline repository itself are sufficient. At least python version 3.6 is required and we recommend to use a virtual environment. Additionally Singularity needs to be installed system wide. On Ubuntu the package is called *singularity-container*. The full installation requires root privileges and might require help of your IT department. Under [Local Singularity](#local-singularity) we describe a workaround for a limited functionality local Singularity installation. We currently test workflows with Singularity version 3.3.0.

Start with creating a virtual environment:

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

Nanopype is based on the Snakemake pipeline engine. With python3.4 onward pip is already installed and you get Snakemake by executing:

```
python3 -m pip install --upgrade snakemake
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
python3 -m pip install . --upgrade
cd ..
```

## Nanopype
Finally install Nanopype from [github.com/giesselmann](https://github.com/giesselmann/nanopype/). If you use conda you find pip in the *bin/* folder of the conda installation. If you use a conda virtual environment use the pip from the *envs/nanopype/bin*.

```
git clone https://github.com/giesselmann/nanopype
cd nanopype
python3 -m pip install . --upgrade
cd ..
```

It is recommended to install a tagged version of Nanopype. Using the 'latest' from master will always pull the most recent Singularity images. If the remaining pipeline is then not regularly updated via ``` git pull ```, pipeline code and container code can diverge. To install a specific version modify the above commands to:

```
git clone --recursive https://github.com/giesselmann/nanopype
cd nanopype
git fetch --tags && git checkout v0.6.0
python3 -m pip install -r requirements.txt
cd ..
```

To deactivate a virtual python environment after installation or usage of the pipeline just type:

```
deactivate
```

for plain and

```
source deactivate
```

for conda virtual environments.

## Local Singularity

If a system wide singularity installation is not available and can not be set up, you can try to install singularity as a user.
The following steps clone the repository and build singularity without the setuid functionality, relying on kernel namespaces at runtime.
The *--prefix* is the installation prefix and must be a writeable path. The *localstatedir* will be created by the make script on the current server. In a cluster environment *localstatedir* needs to be available on a local hard drive on each node!

```
git clone https://github.com/sylabs/singularity.git
cd singularity && git checkout v3.3.0
./mconfig --without-suid --prefix=/path/to/prefix --localstatedir="/scratch/nanopype_singularity"
make -C ./builddir
make -C ./builddir install
```

Singularity requires mksquasfs from squashfs-tools. If not available build and install it using:

```
git clone https://github.com/plougher/squashfs-tools
cd squashfs-tools/squashfs-tools
make
cp *squashfs /path/to/prefix/bin/
```

**Note:** Singularity and mksquasfs must be visible to Snakemake e.g. through the users PATH variable. In a cluster setup this must hold true on every compute node. If your .bashrc becomes sourced on the compute nodes you can simply:

```
echo 'export PATH=/path/to/prefix/bin:${PATH}' >> ~/.bashrc
```

Alternatively if you installed Nanopype and Snakemake to a virtual python environment any executable in the environments bin folder will work. You could therefore create softlinks to the actual installation e.g.:

```
ln -s /path/to/prefix/bin/singularity /path/to/your/environment/bin/singularity
ln -s /path/to/prefix/bin/mksquasfs /path/to/your/environment/bin/mksquasfs
ln -s /path/to/prefix/bin/unsquashfs /path/to/your/environment/bin/unsquashfs
```

The exact approach depends on the local setup and might differ in details.

Finally you need to configure Singularity to only use namespaces when executing the container. Snakemake has a command line argument **--singularity-args** to pass parameters to Singularity. When executing Snakemake with Nanopype use:

```
snakemake --snakefile ~/nanopype/Snakefile --use-singularity --singularity-args=" -u" /some/output_file
```

The leading whitespace is important. Alternatively specify the flag in a user [profile](configuration.md#profiles).

## Configuration
Mission accomplished! Everything else is solved at run time by Snakemake and Nanopype.

!!! warning "Configuration"
    Do not forget to follow the [global](configuration.md) configuration once and for each sample the [local](../usage/general.md) one.

When using the pipeline you'll have to add the **--use-singularity** flag to every Snakemake command. This will pull only the required images in the background. Please also consider setting the **--singularity-prefix** to a common path, otherwise the images will be downloaded for every sample into *./.snakemake/singularity*. If you want to see all available Nanopype Singularity images or check their download sizes visit our [DockerHub](https://cloud.docker.com/repository/list).
