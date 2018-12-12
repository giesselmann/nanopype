# Basecalling

The basecller translates the raw electrical signal from the sequencer into a nucleotide sequence in fastq or fasta format. As input the packed **fast5** files as provided by the [storage](storage.md) module are required.

In order to process the output of one Flow-Cell with the basecaller *albacore* run from within your processing directory:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.albacore.fa.gz

Valid file extensions are fasta/fa, fastq/fq and their gzipped forms. Providing a *runnames.txt* with one runname per line it is possible to process multiple Flow-Cells at once and merge the output into a single file e.g.:

    snakemake --snakefile /path/to/nanopype/Snakefile WA01.albacore.fa.gz

Depending on the application you can choose from one of the following basecallers, listed with their associated configuration options:

## albacore
The ONT closed source software based on a deep neural network. The installer is accessible after login to the community board.
:   * threads_basecalling: 4
    * basecalling_albacore_barcoding: false
    * basecalling_albacore_disable_filtering: true

## guppy
Release announced by ONT.

## flappie
The experimental neural network caller from ONT using flip-flop basecalling.
    * threads_basecalling: 4
