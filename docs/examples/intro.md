# Intro

The tutorial is a step by step guide into the usage of the pipeline. Aside from the preparation steps in the introduction, the different parts work independently from each other. The examples will make use of the test data provided for the unit tests of Nanopype. The following steps assume Nanopype is installed in your home directory ```~/src/nanopype``` and you have activated the virtual environment if used. Also make sure you have run the tests of [installation](../installation/prerequisites.md) and [configuration](../installation/configuration.md).

To get started create an empty directory and copy the read archive from the Nanopype repository into it.

```
mkdir nanopype_tutorial && cd nanopype_tutorial
cp ~/src/nanopype/test/test_data.tar.gz ./
mkdir -p data/raw
tar -zxf test_data.tar.gz -C data/raw
ls -l data/raw
```

***

**Docker only**

Start the container and adjust the name of the version according to what you pulled in the [installation](../installation/docker.md):

```
docker run -it --mount type=bind,source=${HOME}/src/nanopype/,target=/app \
--mount type=bind,source=$(pwd)/data/raw,target=/data/raw \
--mount type=bind,source=$(pwd),target=/data/processing \
--user $(id -u):$(id -g) \
giesselmann/nanopype:v0.7.0
```

***

The last step is to copy the config template to our working directory and adjust the raw data path:


**Singularity and Source only**
```
cp ~/src/nanopype/nanopype.yaml ./
```

With your favorite text editor change the path to:

```
# data paths
storage_data_raw : data/raw
```

***

**Docker only**

The path for *storage_data_raw* is per default set to ```/data/raw```, if you used the above commands to start the container the raw data from your host is mounted to this path in the container. In order to use the same commands in the subsequent tutorial, we link the pipeline from */app* to the */home* directory:

```
cp /app/nanopype.yaml ./
mkdir -p /app/home && export HOME=/app/home
mkdir -p data && mkdir -p ~/src
ln -s /app ~/src/nanopype
```
