# Configuration

Nanopype has two configuration layers: The central **environment** configuration *env.yaml* covers application paths and reference genomes and is set up independent of installation method and operating system once. The environment configuration is stored in the installation directory.

For a project an additional **[workflow](../usage/general.md)** configuration is required providing data sources, tool flags and parameters. The workflow config file *nanopype.yaml* is expected in the root of each project directory. Configuration files are in .yaml format.

## Environment

The default environment configuration **env.yaml** in the pipeline repository assumes all required tools to be available through your systems PATH variable. To use Nanopype with existing installations you may need to adjust their paths. Each tools is configured as key:value pair of tool name and the executable.

```
bin:
    # executable is in PATH variable
    albacore: read_fast5_basecaller.py
    # executable is not in PATH variable
    bedtools: /src/bedtools2/bin/bedtools
```

In order to execute workflows containing alignment steps, the respective reference genomes need to be set up. Each reference is provided as a key (e.g. mm9, mm10, hg19, ..), the genome in fasta format and optionally a chromosome size file if using tools such as *bedGraphToBigWig*.
```
references:
    mm9:
        genome: /path/to/mm9/mm9.fa
        chr_sizes: /path/to/mm9/mm9.chrom.sizes

```

## Profiles



## Cluster configuration

## Custom cluster

An example on how to enable a not yet supported cluster system is given in *profiles/mxq/* of the git repository. Briefly four components are required:

:   * config.yaml - cluster specific command line arguments
    * submit.py - job submission to cluster management
    * status.py - job status request from cluster management
    * jobscript.sh - wrapper script for rules to be executed

**Important:** When working with batches of raw nanopore reads, Nanopype makes use of snakemakes shadow mechanism. A shadow directory is temporary per rule execution and can be placed on per node local storage to reduce network overhead. The shadow prefix e.g. */scratch/local/* is set in the profiles config.yaml. The *--profile* argument tells snakemake to use a specific profile:

    snakemake --profile /path/nanopype/profiles/mxq [OPTIONS...] [FILE]

When running in an environment with **multiple users** the shadow prefix should contain a user specific part to ensure accessibility and to prevent corrupted data. A profile per user is compelling in this case and enforced by Nanopype if not given.
