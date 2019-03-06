# Cluster

Snakemake allows both, cloud and cluster execution of workflows. As of now only cluster execution is implemented in nanopype. For supported cluster engines please refer to the [snakemake](https://snakemake.readthedocs.io/en/stable/executable.html#cluster-execution) documentation. An example on how to enable a not yet supported cluster system is given in *profiles/mxq/* of the git repository. Briefly four components are required:

:   * config.yaml - cluster specific command line arguments
    * submit.py - job submission to cluster management
    * status.py - job status request from cluster management
    * jobscript.sh - wrapper script for rules to be executed

**Important:** When working with batches of raw nanopore reads, nanopype makes use of snakemakes shadow mechanism. A shadow directory is temporary per rule execution and can be placed on per node local storage to reduce network overhead. The shadow prefix e.g. */scratch/local/* is set in the profiles config.yaml. The *--profile* argument tells snakemake to use a specific profile:

    snakemake --profile /path/nanopype/profiles/mxq [OPTIONS...] [FILE]

When running in an environment with **multiple users** the shadow prefix should contain a user specific part to ensure accessibility and to prevent corrupted data. A profile per user is compelling in this case.


## Troubleshooting
There are some common errors that could arise during the installation process. If you encounter one of the following error messages, please consider the respective solution attempts.

**terminated by signal 4**
:   Nanopype is mostly compiling integrated tools from source. In heterogenous cluster environments this can lead to errors if the compilation takes place on a machine supporting modern vector instructions (SSE, AVX, etc.) but execution also uses less recent computers. The error message *terminated by signal 4* indicates an instruction in the software not supported by the underlying hardware. Please re-compile and install the tools from a machine with a common subset of vector instructions in this case.
