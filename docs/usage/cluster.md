# Cluster usage

Snakemake allows both, cloud and cluster execution of workflows. As of now only cluster execution is implemented and tested in Nanopype. The [configuration](../installation/configuration.md) section covers multiple scenarios of integrating supported and custom cluster management systems into the Nanopype workflow. For supported cluster engines please also refer to the [Snakemake](https://snakemake.readthedocs.io/en/stable/executable.html#cluster-execution) documentation. 

Following the steps in the [general](general.md) workflow documentation, the usage of a cluster backend requires only a few additional flags and arguments in the Snakemake command. The use of [profiles](../installation/configuration) is therefore recommended. The following command line options of Snakmake are of particular interest:

**--profile**
:   Path to profile directory with command line arguments and flags. A *config.yaml* is expected to be found in the profile folder


**-n or --dryrun**
:   Do not execute anything, just display what would be done.


**-k or --keep-going**
:   Continue executing independent jobs, even if an error occured.


**--shadow-prefix**
:   Directory to write per rule temporary data to. Some tools working with raw fast5 files need to unpack these creating a large number of temporary files. These rules are set up to use the [shadow](https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#shadow-rules) mechanism of Snakemake. In order to reduce network and fileserver workload the shadow directory can be placed on per node local storage (e.g. /scratch/tmp, /scratch/local, etc). The path should be the same on all nodes but point to a local harddrive on the respective server

**-w or --latency-wait**
:   Time in seconds to wait for output files. On NFS mounted directories in server environments, the output of a rule on a compute node can take a while to appear in the filesystem of the head node.

**--use-singularity and --singularity-prefix**
:   Indicate to use the Singularity implementation of Nanopype. The Singularity prefix can be set to a common path for all processed samples, avoiding multiple downloads of the same images. Singularity images are bound to the version of the pipeline, an update of Nanopype will fetch the most recent ones automatically.

**-j or --jobs or --core**
:   In cluster mode the maximum number of jobs submitted to the queue.


