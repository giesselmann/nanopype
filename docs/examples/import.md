# Data Import

Sequencing data from MinION, GridION or PromethION needs to be imported into a Nanopype compatible raw data folder structure. Recent MinKNOW versions write the reads into 4k batches per file. Nanopype expects a flat folder structure of sequencing runs with a **reads** subfolder containing the batches.

The provided test data contains three runs with one .fast5 batch each:

```
ls -l data/*/
ls -l data/*/reads
```

Note that each run contains a **reads** subfolder and one run is already indexed and contains a file **reads.fofn**. This read index is for instance needed by the demultiplexing module, where reads per barcode are extracted from the raw data archive and processed together.

For the remaining two runs create the read index as follows. Check the todo-list with a dry-run first:

```
snakemake --snakefile ~/src/nanopype/Snakefile data/20200227_FAL08241_FLO-MIN106_SQK-RNA002_sample/reads.fofn -n
```

With the *-n, --dry-run* flag, snakemake plots a list of jobs to execute without doing anything. You will see two types of jobs, **storage_index_batch** and **storage_index_run**. The first one(s) can be executed in parallel, the last one merges the results. Launch the snakemake command without *-n* to index the raw data:

```
snakemake --snakefile ~/src/nanopype/Snakefile data/20200227_FAL08241_FLO-MIN106_SQK-RNA002_sample/reads.fofn
snakemake --snakefile ~/src/nanopype/Snakefile data/20200624_FAN48644_FLO-MIN106_SQK-DCS109_sample/reads.fofn
```

The created indices map each read ID to a batch file:

```
head data/20200624_FAN48644_FLO-MIN106_SQK-DCS109_sample/reads.fofn
```

Mission accomplished! You executed your very first Nanopype workflow!
