# Winnowmap

'Winnowmap is a long-read mapping algorithm optimized for mapping ONT and PacBio reads to repetitive reference sequences.' (https://github.com/marbl/Winnowmap)

To align the reads of one flow cell against reference genome hg38 with *guppy* basecalling and aligner *winnowmap* run from within your processing directory:

    snakemake --snakefile /path/to/nanopype/Snakefile alignments/winnowmap/guppy/WA01/batches/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.bam


## Build and Install

Winnowmap is not installed through the pipelines build system and therefore not available within singularity/docker installations. Please refer to the [winnowmap](https://github.com/marbl/Winnowmap) github for installation instructions and adjust the binary paths in the **site.yaml** inside of the winnowmap plugin folder.


## Folder Structure

The winnowmap plugin integrates the winnowmap aligner with an output sam stream into the pipeline. A meryl-index rule pre-computes the kmer frequencies for the used reference genome. Please also refer to the [alignment](rules/alignment.md) module for further documentation.

```sh
|--alignments/
   |--winnowmap/                                             # Winnowmap alignment
      |--guppy/                                              # Using guppy basecalling
         |--batches/
            |--WA01/
               |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
                  |--0.hg38.sam
```

## Configuration

If provided, the winnowmap plugin will use the following config keys from **nanopype.yaml**:

:   * alignment_meryl_k: 15
    * alignment_winnowmap_flags: '-ax map-ont'

Please note, that the kmer length is only used once during index creation, if you wish to update it, delete the *.meryl* and *.meryl.txt* folder and file respectively.

## Citation

If you use the winnowmap plugin, please cite:

>Chirag Jain, Arang Rhie, Haowen Zhang, Chaudia Chu, Brian Walenz, Sergey Koren and Adam Phillippy. "Weighted minimizer sampling improves long read mapping". Bioinformatics (ISMB proceedings), 2020.
