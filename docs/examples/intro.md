# Intro

The tutorial is a step by step guide into the usage of the pipeline. Aside from the preparation steps in the introduction, the different parts work independently from each other. The examples will make use of the test data provided for the unit tests of Nanopype. The following steps assume Nanopype is installed in your home directory ```~/src/nanopype``` and you have activated the virtual environment if used. Also make sure you have run the tests of [installation](../installation.md) and [configuration](../configuration.md).

To get started create an empty directory and copy the read archive from the nanopype repository into it.

*Docker*
```
docker run -it giesselmann/nanopype
mkdir -p /processing/nanopype_tutorial
cd /processing/nanopype_tutorial
cp /app/test/test_data.tar.gz ./
```

***

*Plain*
```
mkdir nanopype_tutorial
cd nanopype_tutorial
cp ~/src/nanopype/test/test_data.tar.gz ./
```

***

Within the docker Nanopype is installed into ```/app``` folder, subsequent commands need to be adjusted accordingly.

```
mkdir -p data/raw
tar -zxf test_data.tar.gz -C data/raw
ls -l data/raw
```

The last step is to copy the config template to our working directory and adjust the raw data path

```
cp ~/src/nanopype/config.yaml ./
```

With your favorite text editor change the path to:

```
# data paths
storage_data_raw : data/raw
```
