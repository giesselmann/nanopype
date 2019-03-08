# Cluster

Snakemake allows both, cloud and cluster execution of workflows. As of now only cluster execution is implemented in Nanopype. For supported cluster engines please refer to the [snakemake](https://snakemake.readthedocs.io/en/stable/executable.html#cluster-execution) documentation. Briefly every Snakemake command can be extended by e.g.:

    snakemake --cluster "qsub {threads}"

All Nanopype workflows specify a threads, time_min and mem_mb resource. If supported by the cluster engine you could therefore use:

    snakemake --cluster "qsub {threads} --runtime {resources.time_min} --memory {resources.mem_mb}"

An example on how to enable a not yet supported cluster system is given in *profiles/mxq/* of the git repository. Briefly four components are required:

:   * config.yaml - cluster specific command line arguments
    * submit.py - job submission to cluster management
    * status.py - job status request from cluster management
    * jobscript.sh - wrapper script for rules to be executed

**Important:** When working with batches of raw nanopore reads, Nanopype makes use of Snakemake's shadow mechanism. A shadow directory is temporary per rule execution and can be placed on per node local storage to reduce network overhead. The shadow prefix e.g. */scratch/local/* is set in the profiles config.yaml. The *--profile* argument tells Snakemake to use a specific profile:

    snakemake --profile /path/nanopype/profiles/mxq [OPTIONS...] [FILE]

When running in an environment with **multiple users** the shadow prefix should contain a user specific part to ensure accessibility and to prevent corrupted data. A profile per user is compelling in this case and enforced by Nanopype if not given.
