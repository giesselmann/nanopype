# Intro

The tutorial is a step by step guide into the usage of the pipeline. Aside from the preparation steps in the introduction, the different parts work independently from each other. The examples will make use of the test data provided for the unit tests of Nanopype. The following steps assume Nanopype is installed in your home directory ```~/src/nanopype``` and you have activated the virtual environment if used. Also make sure you have run the tests of [installation](../installation/prerequisites.md) and [configuration](../installation/configuration.md).

To get started create an empty directory and download the test reads:

```
mkdir nanopype_tutorial && cd nanopype_tutorial
wget https://owww.molgen.mpg.de/~nanopype/unit_tests/index.fofn
wget -nH --cut-dirs=2 -x -i <(cat index.fofn | grep -E 'ref/|data/' | sed 's#^#https://owww.molgen.mpg.de/~nanopype/unit_tests/#')
ls -l data/raw
ls -l ref/
cp ~/src/nanopype/nanopype.yaml ./
```

***

**Docker only**

Start the container and adjust the name of the version according to what you pulled in the [installation](../installation/docker.md):

```
docker run -it --mount type=bind,source=${HOME}/src/nanopype/,target=/app \
--mount type=bind,source=$(pwd)/,target=/nanopype_tutorial/ \
--user $(id -u):$(id -g) \
nanopype/nanopype:v1.0.0
```

The path for *storage_data_raw* is per default set to ```/data/raw```, if you used the above commands to start the container the raw data from your host is mounted to this path in the container. In order to use the same commands in the subsequent tutorial, we link the pipeline from */app* to the */home* directory:

```
cd /nanopype_tutorial
mkdir -p /app/home && export HOME=/app/home
mkdir -p ~/src && ln -s /app ~/src/nanopype
```

***

Each part of the tutorial covers a different aspect of Snakemake and Nanopype. If you're new to this field, it is recommended to run them in order. If you're only interested in a particular function of Nanopype, feel free to fast-forward to any section:
