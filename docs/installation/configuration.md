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

??? info "example env.yaml"
    ```
    references:
        mm9:
            genome: /project/bioinf_meissner/references/mm9/mm9.fa
            chr_sizes: /project/bioinf_meissner/references/mm9/mm9.chrom.sizes
        mm10:
            genome: /project/bioinf_meissner/references/mm10/mm10.fa
            chr_sizes: /project/bioinf_meissner/references/mm10/mm10.chrom.sizes
        hg19:
            genome: /project/bioinf_meissner/references/hg19/hg19.fa
            chr_sizes: /project/bioinf_meissner/references/hg19/hg19.chrom.sizes
        hg38:
            genome: /project/bioinf_meissner/references/hg38/hg38.fa
            chr_sizes: /project/bioinf_meissner/references/hg38/hg38.chrom.sizes

    bin:
        albacore: /project/minion/bin/read_fast5_basecaller.py
        flappie: /project/minion/bin/flappie
        guppy: /project/minion/bin/guppy_basecaller
        bedtools: /project/minion/bin/bedtools
        graphmap: /project/minion/bin/graphmap
        minimap2: /project/minion/bin/minimap2
        nanopolish: /project/minion/bin/nanopolish
        ngmlr: /project/minion/bin/ngmlr
        samtools: /project/minion/bin/samtools
        sniffles: /project/minion/bin/sniffles
        deepbinner: /project/minion/bin/deepbinner-runner.py
        bedGraphToBigWig: /project/minion/bin/bedGraphToBigWig
    ```


## Profiles

Snakemake supports the creation of [profiles](https://snakemake.readthedocs.io/en/stable/executable.html#profiles) to store flags and options for a particular environment. A profile for a workflow is loaded from the Snakemake command line via:

    snakemake --profile myprofile ...

searching globally (*/etc/xdg/snakemake*) locally (*$HOME/.config/snakemake*) for folders with name *myprofile*. Theese folders are expected to contain a **config.yaml** with any of Snakemakes command line parameters. An example profile is given in *nanopype/profiles/mxq* which can be used with

    snakemake --profile /path/to/nanopype/profiles/mxq ...

Additional profiles can be found at [https://github.com/snakemake-profiles/doc](https://github.com/snakemake-profiles/doc).

??? info "example config.yaml"
    ```
    # per node local storage
    shadow-prefix: "/scratch/local2/"
    # jobscripts
    cluster: "mxq-submit.py"
    cluster-status: "mxq-status.py"
    jobscript: "mxq-jobscript.sh"
    # params
    latency-wait: 600
    jobs: 2048
    restart-times: 3
    immediate-submit: false
    ```

## Cluster configuration

The [cluster configuration](https://snakemake.readthedocs.io/en/stable/snakefiles/configuration.html#cluster-configuration) of Snakemake is separated from the workflow and can be provided in .json or .yaml format. The configuration is composed of default settings mapping to all rules (e.g. basecalling, alignment, etc.) and rule specific settings enabling a fine grained control of resources such as memory and run time.

??? info "example cluster.json for LSF/BSUB ([source](https://snakemake.readthedocs.io/en/stable/snakefiles/configuration.html#cluster-configuration))"
    ```
    {
        "__default__" :
        {
            "queue"     : "medium_priority",
            "nCPUs"     : "16",
            "memory"    : 20000,
            "resources" : "\"select[mem>20000] rusage[mem=20000] span[hosts=1]\"",
            "name"      : "JOBNAME.{rule}.{wildcards}",
            "output"    : "logs/cluster/{rule}.{wildcards}.out",
            "error"     : "logs/cluster/{rule}.{wildcards}.err"
        },

        "minimap2" :
        {
            "memory"    : 30000,
            "resources" : "\"select[mem>30000] rusage[mem=30000] span[hosts=1]\"",
        }
    }
    ```

Parameters of the cluster config are accessible inside the cluster submission command:

    snakemake --cluster-config cluster.json --cluster "sbatch -A {cluster.account} -p {cluster.partition} -n {cluster.n}  -t {cluster.time}"

Furthermore Nanopype specifies per rule a configurable number of threads and calculates the estimated run time and memory consumption accordingly. Integration and customization of these parameters is described in the [cluster](../usage/cluster.md) chapter of the workflow section.


## Custom cluster integration

An example on how to enable a not yet supported cluster system is given in *profiles/mxq/* of the git repository. Briefly four components are required:

:   * config.yaml - cluster specific command line arguments
    * submit.py - job submission to cluster management
    * status.py - job status request from cluster management
    * jobscript.sh - wrapper script for rules to be executed

**Important:** When working with batches of raw nanopore reads, Nanopype makes use of Snakemakes shadow mechanism. A shadow directory is temporary per rule execution and can be placed on per node local storage to reduce network overhead. The shadow prefix e.g. */scratch/local/* is set in the profiles config.yaml. The *--profile* argument tells Snakemake to use a specific profile:

    snakemake --profile /path/nanopype/profiles/mxq [OPTIONS...] [FILE]

When running in an environment with **multiple users** the shadow prefix should contain a user specific part to ensure accessibility and to prevent corrupted data. A profile per user is compelling in this case and enforced by Nanopype if not given.
