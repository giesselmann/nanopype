# Configuration

Nanopype has two configuration layers: The central **environment** configuration covers application paths and reference genomes. The environment configuration is stored in the installation directory. For a project an additional **workflow** configuration is required providing data sources, tool flags and parameters. The workflow config is stored in the root of each project directory. Configuration files are in .yaml format.

## File Structure

**Binaries**
:	Executables of nanopype and and its integrated tools can be installed system wide or build from source by the user. In case of cluster execution of workflows they must be accessible from each node.

**Raw data**
:	Raw nanopore read data is organized in directories per flow-cell. The name is used to parse important experimental information such as flow-cell type and sequencing kit.
	A suggested pattern is *20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01* with fixed first four fields and an arbitrary number of user defined tags at the end.
	Nanopype will search a *reads/* subfolder for tar archives containing packed fast5 files with signal values from the sequencer. A *reads.fofn* can be created to index the run and enable efficient extraction of reads of interest.

**Processing**
:	One or multiple sequencing runs are processed batch-wise and merged into tracks. A working directory requires a local workflow configuration. Modules create subdirectories with batch results for e.g. sequences, alignments, methylation calls.


## Environment

The default environment configuration **env.yaml** assumes all required tools to be available through your systems PATH variable. To use nanopype with existing installations you may need to adjust their paths. Each tools is configured as key:value pair of tool name and the executable. 

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

## Workflow

The default workflow configuration **config.yaml** in the installation directory serves as a template and needs to be copied to each working directory. The meaning of tool specific parameters is explained in the **Modules** section. 
Raw data is stored in per flow-cell run folders. Nanopype is parsing the Flow-Cell ID, its type and the used sequencing kit from the name. A possible naming pattern is:

> 20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01

with the corresponding configuration entries:

```
storage_runname:
    delimiter: '_'
    field_ID: 1
    field_flowcell: 2
    filed_kit: 3
```

## Cluster

Snakemake allows both, cloud and cluster execution of workflows. As of now only cluster execution is implemented in nanopype. For supported cluster engines please refer to the [snakemake](https://snakemake.readthedocs.io/en/stable/executable.html#cluster-execution) documentation. An example on how to enable a not yet supported cluster system is given in *profiles/mxq/* of the git repository. Briefly four components are required:

:	* config.yaml - cluster specific command line arguments
    * submit.py - job submission to cluster management
    * status.py - job status request from cluster management
	* jobscript.sh - wrapper script for rules to be executed
	
**Important:** When working with batches of raw nanopore reads, nanopype makes use of snakemakes shadow mechanism. A shadow directory is temporary per rule execution and can be placed on per node local storage to reduce network overhead. The shadow prefix e.g. */scratch/local/* is set in the profiles config.yaml. The *--profile* argument tells snakemake to use a specific profile:

    snakemake --profile /path/nanopype/profiles/mxq [OPTIONS...] [FILE]

When running in an environment with **multiple users** the shadow prefix should contain a user specific part to ensure accessibility and to prevent corrupted data. A profile per user is compelling in this case.
    
## Test

To test if the installation and configuration was successful, we provide a small MinION dataset of a human cell line.

### Python

    python3 test/test_rules.py

### Docker

    docker run -it --mount type=bind,source=./,target=/app nanopype
    cd /app
    python3 test/test_rules.py

