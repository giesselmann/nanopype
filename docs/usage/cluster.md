# Cluster usage

Snakemake allows both, cloud and cluster execution of workflows. As of now only cluster execution is implemented in Nanopype. For supported cluster engines please also refer to the [Snakemake](https://snakemake.readthedocs.io/en/stable/executable.html#cluster-execution) documentation. Briefly every Snakemake command can be extended by e.g.:

    snakemake --cluster "qsub {threads}"

The --cluster option can either be a command string or a script handling the job-script as single positional argument. In case of the above sample, wildcards in curly brackets are substituted by Snakemake before invoking the command. All Nanopype workflows specify threads and time_min and mem_mb resources. If supported by the cluster engine you could therefore use:

    snakemake --cluster "qsub {threads} --runtime {resources.time_min} --memory {resources.mem_mb}"

Especially in cluster environments the use of [profiles](../installation/configuration) is recommended. The following command line options of Snakmake are of particular interest and require 
