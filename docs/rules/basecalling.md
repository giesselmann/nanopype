# Basecalling

The basecaller translates the raw electrical signal from the sequencer into a nucleotide sequence in fastq or fasta format. As input the packed **fast5** files as provided by the [storage](storage.md) module are required.

In order to process the output of one flow cell with the basecaller *albacore* run from within your processing directory:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/albacore/runs/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.fastq.gz

Valid file extensions are fasta/fa, fastq/fq in gzipped form. Providing a *runnames.txt* with one run name per line it is possible to process multiple flow cells at once and merge the output into a single file e.g.:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/albacore/WA01.fastq.gz

The tag *WA01* is arbitrary and may describe a corresponding experiment or cell line. Furthermore a basic quality control of the flow cell can be obtained by running:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/albacore/WA01.fastq.pdf

The content of the QC depends on the basecaller and format. The sequence quality for instance is only stored in fastq format.

## Folder structure

The basecalling module can create the following file structure relative to the working directory:

```sh
|--sequences/
   |--albacore/                                                 # Albacore basecaller
      |--runs/
         |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
            |--0.fastq.gz                                       # Sequence batches
            |--1.fastq.gz
             ...
         |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.fastq.gz
         |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.fastq.pdf
      |--WA01.fastq.gz
      |--WA01.fastq.pdf
   |--guppy/                                                    # Guppy basecaller
      |--...
```

## Tools
Depending on the application you can choose from one of the following basecallers, listed with their associated configuration options. Downstream applications making use of the basecalling module can either enforce a specific basecaller or used the default configuration:

:   * threads_basecalling: 4

### Albacore
The ONT closed source software based on a deep neural network. The installer is accessible after login to the community board.

:   * basecalling_albacore_barcoding: false
    * basecalling_albacore_disable_filtering: true
    * basecalling_albacore_flags: ''

### Guppy
Pre-Release within ONT-community.

:   * basecalling_guppy_qscore_filter: 0
    * basecalling_guppy_flags: ''

### Flappie
The experimental neural network caller from ONT using flip-flop basecalling.

:   * basecalling_flappie_model: 'r941_5mC'
    * basecalling_flappie_flags: ''
