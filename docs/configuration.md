# Configuration

Nanopype has two configuration layers: The installation bound central environment configuration covers tool paths and reference genomes. The environment configuration is stored in the installation directory. For a project an additional workflow configuration is required providing data sources, tool flags and parameters. The workflow config is stored in the root of each project directory. Configuration files are in .yaml format.

## Environment

The default environment configuration **env.yaml** assumes all required tools to be available through your systems PATH variable. To use nanopype with existing installations you may need to adjust their paths. Each tools is configured as key:value pair of tool name and the executable. 

```
bin:
    # tool is in PATH variable
    albacore: read_fast5_basecaller.py
    # tool is not in PATH variable
    bedtools: /src/bedtools2/bin/bedtools
```

In order to execute workflows containing alignment steps, the respective reference genomes need to be set up. Each reference is provided as a key (e.g. mm9, mm10, hg19, ..), the genome in fasta format and optionally a chromosome size file if using tools such as *bedGraphToBigWig*.
```
references:
    mm9:
        genome: /path/to/mm9/mm9.fa
        chr_sizes: /path/to/mm9/mm9.chrom.sizes
        
```

## Workflow

The default workflow configuration **config.yaml** in the installation directory serves as a template and needs to be copied to each working directory. The meaning of tool specific parameters is explained in the **Modules** section. 
Raw data is stored in per flow-cell run folders. Nanopype is parsing the Flow-Cell ID, its type and the used sequencing kit from the name. A possible naming pattern is:

> 20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01

with the delimiter '_', ID in field 1, type in field 2 and sequencing kit in field 3.

## Cluster

Snakemake supports both, cloud and cluster execution of workflows. As of now only cluster execution is implemented in nanopype. For supported cluster engines please refer to the [snakemake](https://snakemake.readthedocs.io/en/stable/executable.html#cluster-execution) documentation. An example on how to enable a not yet supported cluster system is given in the *profiles/mxq/*. Briefly four components are required:

:	* config.yaml - cluster specific command line arguments
	* jobscript.sh - wrapper script for rules to be executed
	* status.py - job status request from cluster management
	* submit.py - job submission to cluster management
	
When working with batches of raw nanopore reads, nanopype makes use of snakemakes shadow mechanism. A shadow directory is temporary per rule execution and can be placed on per node local storage to reduce network overhead. The shadow prefix e.g. */scratch/local/* is set in the config.yaml






