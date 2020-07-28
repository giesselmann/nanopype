# Updates

We deploy new versions of Nanopype for both important updates in the included tools and for additional features of the pipeline. We use semantic versioning in the format v1.0.3 (MAJOR.MINOR.PATCH). The major version is increased on significant changes in the pipeline. Any version update of included tools forces a new minor version. Pipeline releases with the same major and minor version are expected to produce the same results across installations.

Before starting the update process, please make sure to backup your configuration files. Changes to the Nanopype repository (e.g. *env.yaml*) will be lost after the update and have to be restored manually.

Independant of the installation method, the repository of the pipeline needs to be updated. The examples illustrate an update to version v0.7.0. Please activate the virtual environment of nanopype, if you used one during initial installation.

```
cd /path/to/nanopype
git fetch --tags
git checkout -f v0.7.0 && git clean -dfx && git gc --auto
python3 -m pip install -r requirements.txt --upgrade
```

The pipeline repository is now in a default state, changes made to the environment configuration in **env.yaml** need to be restored. Please also note that workflow configurations might change between pipeline releases. Compare the default **nanopype.yaml** in the repository with the one in the working directory to identify additional options.


## Singularity

No specific steps are needed. You might consider deleting old Singularity images before running the pipeline. These are either in the hidden *.snakemake* folder of each working directory or at a common location when using *--singularity-prefix*


## Source

When running the pipeline with tools built from source, the update includes re-building those. Depending on the extent of the patch, only a subset of tools is affected. Assuming your pipeline binaries are located in an isolated folder it is easiest to delete all, keep the sources from the first installation and run the same commands as described in the [installation](installation/src.md) section.

According to the versions listed in the [release notes](release-notes.md) tools can be individually upgraded. The following example shows how to update the basecaller guppy.

```
rm ~/bin/guppy_basecaller
cd /path/to/nanopype
snakemake --snakefile rules/install.smk --directory ~/ bin/guppy_basecaller
```

The build rules are implemented as Snakemake workflows, thus deleting the output file (the binary) triggers a re-run of the build/download process.

All tools can be re-installed by forcing a Snakemake run. This is safer but takes considerably more time.

```
cd /path/to/nanopype
snakemake --snakefile rules/install.smk --directory ~/ all --forceall
```


## Docker

The docker update is straightforward, just pull any updated version with e.g.:

```
docker pull nanopype/nanopype:v0.7.0
```

You can remove previous installations by running

```
docker images                            # list all images
docker rmi nanopype/nanopype:v0.6.0      # remove tagged version
```


## Configuration

The pipeline configuration on [environment](installation/configuration.md) and [workflow](usage/general.md) level might be affected by an update. Please compare the default keys in the **env.yaml** and **nanopype.yaml** in the repository with the copies in your system and workflow directories. Start new workflows with the template from the repository.
