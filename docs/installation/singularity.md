# Singularity

In order to use the Singularity driven version of Nanopype a working python3 with Snakemake and the pipeline repository itself are sufficient. At least python version 3.4 is required and we recommend to use a virtual environment. Additionally Singularity needs to be installed system wide. On Ubuntu the package is called *singularity-container*. The installation requires root privileges and might require help of your IT department.

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

When using the pipeline you'll have to add the **--use-singularity** flag to every Snakemake command. This will pull only the required images in the background. Please also consider setting the **--singularity-prefix** to a common path, otherwise the images will be downloaded for every sample into *./.snakemake/singularity*. If you want to see all available Nanopype Singularity images or check their download sizes visit our [DockerHub](https://cloud.docker.com/repository/list).
