# Configuration

* Where is ```env.yaml``` located? (Environment section)
* Make statement in the beginning that this is now independent of OS
* Explain the suggested pattern in file structure better so that is very clear what each position means and directly when it is mentioned for the first time
* Provide download sources for genomic files (link to UCSC)
* Make clear that workflow config can be found under usage

Nanopype has two configuration layers: The central **environment** configuration covers application paths and reference genomes. The environment configuration is stored in the installation directory. For a project an additional **workflow** configuration is required providing data sources, tool flags and parameters. The workflow config is stored in the root of each project directory. Configuration files are in .yaml format.

## File Structure

**Binaries**
:   Executables of Nanopype and and its integrated tools can be installed system wide or build from source by the user. In case of cluster execution of workflows they must be accessible from each node.

**Raw data**
:   Raw nanopore read data is organized in directories per flow cell. The name is used to parse important experimental information such as flow cell type and sequencing kit.
    A suggested pattern is *20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01* with fixed first four fields and an arbitrary number of user defined tags at the end.
    Nanopype will search a *reads/* subfolder for tar archives containing packed fast5 files with signal values from the sequencer. A *reads.fofn* can be created to index the run and enable efficient extraction of reads of interest.

**Processing**
:   One or multiple sequencing runs are processed batch-wise and merged into tracks. A working directory requires a local workflow configuration. Modules create subdirectories with batch results for e.g. sequences, alignments, methylation calls.


## Environment

The default environment configuration **env.yaml** assumes all required tools to be available through your systems PATH variable. To use Nanopype with existing installations you may need to adjust their paths. Each tools is configured as key:value pair of tool name and the executable.

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
