# Basecalling

The basecller translates the raw electrical signal from the sequencer into a nucleotide sequence in fastq or fasta format. As input the packed **fast5** files as provided by the [storage](storage.md) module are required.

In order to process the output of one Flow-Cell with the basecaller *albacore* run from within your processing directory:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.albacore.fa.gz

Valid file extensions are fasta/fa, fastq/fq and their gzipped forms. Depending on the application you can choose from one of the following basecallers, listed with their associated configuration options:

## Albacore
The ONT closed source software based on a deep neural network. The installer is accessible after login to the community board.
:   * threads_basecalling: 4
    * basecalling_albacore_barcoding: false
    * basecalling_albacore_disable_filtering: true
