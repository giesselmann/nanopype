# Storage

The storage module of nanopype covers the import, indexing and extraction of raw nanopore reads. In general the raw data directory is expected to have one folder per Flow-Cell with a subfolder *reads* containing the packed *.fast5* files. 

```sh
|--/data/raw/
   |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/   # One Flow-Cell
      |--reads/
         |--0.tar                                     # Packed .fast5
         |--1.tar
          ...
         |--reads.fofn                                # Index file
```
## Import

To pack reads e.g. from the MinKNOW output folder we provide an import script *nanopype_import.py* in the scripts folder of the repository. The basic usage is:

    python3 scripts/nanopype_import.py /data/raw/runname/ /path/to/import

You can specify one or more import directories, also by using wildcards in the path. This is useful after restarting an experiment and importing every folder containing a specific Flow-Cell ID. Consider changing the batch size in case of amplicon or RNA sequencing with significantly more but in general shorter reads. 
The order of reads in the archives is **not** guaranteed to be the same as in the output folders of MinKNOW. Running the script with the same arguments twice will validate the import process and report any inconsistency between import and raw data directories.

## Indexing

An index file *reads.fofn* with one line per read containing the ID and the archive the read is stored in is helpful if later only a subset of the whole dataset needs to be processed. The indexing is triggered from the processing directory by executing e.g.:

    snakemake --snakefile /path/to/nanopype/Snakefile /data/raw/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/reads.fofn

Together with the import, this is the only rule requiring **write access** to the raw data. We highly recommend, running it once after the experiment and making the run folder write protected afterwards with e.g.:

    chmod 444 -R /data/raw/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01

## Extraction

It is possible to extract a **subset** of fast5 files from the packed and indexed run. Extraction requires a previously indexed run, a list of read IDs and works by requesting a directory from nanopype:

    snakemake --snakefile /path/to/nanopype/Snakefile subset/roi/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01

With this command the extraction rule expects an input file subset/roi.txt with one read ID per line. Multiple regions of interest are supported by multiple ID files.

    b4782c09-6edc-4a1e-aad9-ba7d740723bc
    1ab15b74-65a1-42d0-9ff6-1d7276c30e46
    5d18f246-e96b-43ff-aea7-4b55029929ef
    ...

To extract reads covering a region of interest from multiple runs, provide a runnames.txt in the processing directory with one line per sequencing run:

    20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01
    20180202_FAH67890_FLO-MIN106_SQK-LSK108_WA01

And execute:

    snakemake --snakefile /path/to/nanopype/Snakefile subset/roi.done

For this rule a flag file indicating completion is required since the exact output is unknown and the output directory might already be existent.