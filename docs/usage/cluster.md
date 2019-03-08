# Cluster usage

Snakemake allows both, cloud and cluster execution of workflows. As of now only cluster execution is implemented in Nanopype. For supported cluster engines please refer to the [snakemake](https://snakemake.readthedocs.io/en/stable/executable.html#cluster-execution) documentation. Briefly every Snakemake command can be extended by e.g.:

    snakemake --cluster "qsub {threads}"

All Nanopype workflows specify a threads, time_min and mem_mb resource. If supported by the cluster engine you could therefore use:

    snakemake --cluster "qsub {threads} --runtime {resources.time_min} --memory {resources.mem_mb}"
