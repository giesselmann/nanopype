# Usage

## Workflow config

The default workflow configuration **config.yaml** in the installation directory serves as a template and needs to be copied to each working directory. The meaning of tool specific parameters is explained in the **Modules** section.
Raw data is stored in per flow cell run folders. Nanopype is parsing the flow cell ID, its type and the used sequencing kit from the name. A possible naming pattern is:

> 20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01

with the corresponding configuration entries:

```
storage_runname:
    delimiter: '_'
    field_ID: 1
    field_flowcell: 2
    filed_kit: 3
```

## Snakemake

The basic concept of snakemake and thus also nanopype is to request an output file which can be generated from one or more input files. Snakemake will recursively build a graph and determine required intermediate or temporary data to be processed. In general you can run snakemake from within your processing directory with

    snakemake --snakefile /path/to/nanopype/Snakefile [OPTIONS...] [FILE]

or from the installation path with specifying the working directory:

    snakemake --directory /path/to/processing [OPTIONS...] [FILE]

Nanopype expects a **config.yaml** in the root of the processing directory. A template with default values is found in the nanopype repository. You can either edit the parameters within the file or override them from the command line:

    snakemake [OPTIONS...] [FILE] --config threads_basecalling=16

For all available options please refer to the [snakemake](https://snakemake.readthedocs.io/en/stable) documentation. Particularly interesting are:

* -n / --dryrun : Print required steps but do not execute, useful to check before e.g. cluster submissions
* -j / --cores / --jobs : In local mode: number of provided cores; In cluster mode: number of jobs submitted at the same time
* -k / --keep-going : Continue execution of independent jobs, in case of errors
