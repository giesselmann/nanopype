# Usage

Nanopype is based on the three key components binaries, raw data handling and processing. After finishing the [installation](../installation/prerequisites.md) and [environment](../installation/configuration.md) configuration, the pipeline is ready to process nanopore data sets. If you use Nanopype for the first time you might consider following the [tutorial](../examples/intro.md) first.

The default workflow configuration **nanopype.yaml** in the installation directory of Nanopype serves as a template and needs to be copied to each working directory. The file is required in each processing directory and parsed in every invocation of the pipeline. The meaning of tool specific parameters is documented in the Modules section.

!!! error "Caution"
    The parameters in the config file have significant impact on the computed output. In contrast to the incorporated tools the configuration is not controlled or versioned by Nanopype. Changing entries without re-running the pipeline will lead to inconsistency between config and processed data.


## Snakemake basics

The basic concept of Snakemake and thus also Nanopype is to request an output file which can be generated from one or more input files. Snakemake will recursively build a graph and determine required intermediate or temporary data to be processed. In general you can run Snakemake from within your processing directory with

    snakemake --snakefile /path/to/nanopype/Snakefile [OPTIONS...] [FILE]

or from the installation path with specifying the working directory:

    snakemake --directory /path/to/processing [OPTIONS...] [FILE]

Nanopype expects a **nanopype.yaml** in the root of the processing directory. A template with default values is found in the Nanopype repository. You can either edit the parameters within the file or override them from the command line:

    snakemake [OPTIONS...] [FILE] --config threads_basecalling=16

For all available snakemake command line options please also refer to the [snakemake](https://snakemake.readthedocs.io/en/stable) documentation. Particularly interesting are:

* -n / --dryrun : Print required steps but do not execute, useful to check before e.g. cluster submissions
* -j / --cores / --jobs : In local mode: number of provided cores; In cluster mode: number of jobs submitted at the same time
* -k / --keep-going : Continue execution of independent jobs, in case of errors


## Singularity

Using Nanopype with the Singularity installation method is recommended. Environment and workflow configuration remain the same as above, the Snakemake command line needs to be extended to:

    snakemake --snakefile /path/to/nanopype/Snakefile --use-singularity [OPTIONS...] [FILE]

Nanopype is detecting its current version from the cloned repository and will fetch the respective Singularity containers. Per default these images are stored in the hidden *.snakemake* folder in the current working directory. For multiple parallel workflows the flag *--singularity-prefix* can be set to fetch and save images only once. Setting the prefix in a [profile](../installation/configuration.md#profiles) along with other static flags is our suggestion.


## Raw data archives

Raw nanopore read data is organized in directories per flow cell. Their name can be used to encode important experimental information such as flow cell type, kit and IDs. The name **must** at least contain the flow cell type and the sequencing kit which are used by the basecalling module. Furthermore a *reads* sub folder containing batches of raw nanopore reads in *.tar* or bulk-*.fast5* format is required.

??? info "raw data archive formats"
    In previous versions of MinKNOW each read was stored into a single .fast5 file. A large number of single files leads especially on Linux like systems to directories which are difficult to copy, search and handle in general. To address this issue Nanopype provides an import tool in *scripts/nanopype_import.py* to package batches of e.g. 4000 .fast5 files in tar-archives. Current versions of MinKNOW do fully utilize the capabilities of the underlying hdf5 format and write a configurable number or reads into a bulk-fast5 file.
    Nanopype can operate on both, packaged single reads and bulk format. Furthermore algorithms requiring fast5 access can be fed with single read fast5 files to maintain backwards compatibility.

A suggested naming pattern for per flow cell directories is:

<center>
**20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01**
</center>

with fixed first four fields separated by underscores and an arbitrary number of user defined tags at the end.

Copying the **nanopype.yaml** from the pipeline repository into the processing directory is the first step before further local workflow configuration and processing.


## Workflow config

The entry *storage_data_raw* is the common base path of the previously described data directories per flow cell. It can be a relative or absolute path and must for cluster usage be accessible from all computing nodes.
With *threads_[module]* the number of threads used per batch and specific module can be controlled. The overall number of available threads is set at run time.

Nanopype supports merging of multiple flow cells into a single track. A **runnames.txt** in the processing directory with one raw data folder name per line is required in that case. Lines starting with # are treated as comments, empty lines are ignored.

Whereas the following command would trigger basecalling of a single flow cell:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/guppy/WA01/batches/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.fastq.gz

the next will trigger basecalling for all runs listed in *runnames.txt* and merge the results in the end:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/guppy/WA01.fastq.gz

The name of the output file is called a **tag** and is in this case is arbitrary. Special tags exist for barcoded runs as described in the [demultiplexing](../rules/demux.md) module. The extension must be either fasta.gz or fastq.gz.


## Processing examples

If available Nanopype tries to implement and provide multiple, possibly competing tools for the same task. The alignment module for instance allows currently to select from three different long read aligners namely minimap2, graphmap2 and ngmlr.
A key design of Nanopype is that the executed pipeline is reflected in the structure of the output directory. Taking the alignment example, exchanging the aligner in a workflow becomes as simple as:

    snakemake --snakefile /path/to/nanopype/Snakefile alignments/minimap2/guppy/WA01.hg38.bam -j16
    snakemake --snakefile /path/to/nanopype/Snakefile alignments/graphmap2/guppy/WA01.hg38.bam -j16
    snakemake --snakefile /path/to/nanopype/Snakefile alignments/ngmlr/guppy/WA01.hg38.bam -j16

All three commands will make use of the same basecalling results but create different .bam files.


## Temporary data

In the processing stage Nanopype can create a significant amount of temporary data which is not automatically cleaned up and caused by the batch processing approach. As an example, the merged alignment of multiple runs will create the following output directory structure:

```sh
|--alignments/
   |--minimap2/                                              # Minimap2 alignment
      |--guppy/                                              # Using guppy basecalling
         |--batches
            |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
               |--0.hg38.bam
               |--1.hg38.bam
               ...
            |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.bam
         |--WA01.hg38.bam
```

Aside from the final output file *WA01.hg38.bam* the individual .bam files per run and the set of batch alignment files in the *batches* sub folder contain the same information. Since other modules of the pipeline might later require the batch alignment output as input files, the deletion of the intermediate results is left to the user.

Nanopype provides a set of cleanup rules to delete the batch processing output. Per module these rules delete everything inside of the **batches** folder. The cleanup is invoked by the rule name from within the working directory for e.g. the basecalling module:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences_clean

!!! error "Caution"
    Deleting the batch output of a module impacts the execution of other workflows as well and should be used with caution at the end of an analysis workflow. Running for instance a structural variation detection requires a merged .bam file. Deleting the batch output of the alignment module afterwards would lead in a later processing of e.g. methylation rates to the reprocessing of the alignment in batches.

The full list of available cleaning rules is given below:

    * sequences_clean
    * alignment_clean
    * methylation_clean
    * sv_clean
    * demux_clean
    * transcript_isoforms_clean
