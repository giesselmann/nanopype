# Demultiplexing

With barcoded libraries nanopore sequencing allows to pool multiple samples on a single flow cell. Demultiplexing describes the classification of barcodes per read and the assignment of read groups. The output of the demultiplexing module is batches of read IDs belonging to a detected barcode.

Aside from explicit demultiplexing the module supports mapping of previously introduced tags to barcodes. A **barcodes.yaml** in the working directory is detected by Nanopype and can map raw demux output to tags:

??? info "example barcodes.yaml"
    ```
    __default__:
        NB01 : '1'
        NB02 : '2'
    20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01:
        NB01 : '3'
        NB02 : '4'
    ```

The file may contain a `__default__` mapping, applied to any not listed run as well as run specific mappings. Each mapping is a key:value pair of tag and barcode. For different runs, the same tag can map to different barcodes allowing the efficient usage of available barcodes in the sequencing kit. Without running the demultiplexing explicitly, an alignment of only one barcode can be obtained by running:

```
snakemake --snakefile /path/to/nanopype/Snakefile alignments/minimap2/guppy/WA01.NB01.hg38.bam
```

Nanopype will detect *NB01* in the tag to be listed in *barcodes.yaml*, start demultiplexing, create batches of read IDs with barcode 1 and run basecalling and alignment only for this subset of reads.

Please note that the different tools name the barcodes differently, from deepbinner barcode NB01 is named '1' while guppy produces 'barcode01'. To verify the naming and the present barcodes in a specific run use e.g.:

```
snakemake --snakefile /path/to/nanopype/Snakefile demux/guppy/barcodes/20180101_FAH12345_FLO-MIN106_SQK-RBK004_WA01
```

The **barcodes.yaml** needs to match the naming pattern of the used tool, otherwise no reads get assigned to the tag.

## Folder structure

The demultiplexing module can create the following file structure relative to the working directory:

```sh
|--demux/
   |--deepbinner/                                          # Deepbinner neural network
      |--batches/
         |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
            |--0.tsv                                       # classified batches
            |--1.tsv
          ...
      |--barcodes/
         |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
            |--1/                                          # raw barcode for tag:barcode mapping
               |--0.txt                                    # 4k reads of barcode 1
               |--1.txt
            |--2/
   |--guppy/
      |--barcodes/
         |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
            |--barcode01/
               |--0.tsv
```

## Tools

The demultiplexing module includes the following tools and their respective configuration, shared config variables are:

```
threads_demux: 4
demux_batch_size: 4000
demux_default: 'deepbinner'
```

Demultiplexing is not encoded into the output paths of the subsequent workflows, with the 'demux_default' option the demultiplexer is configured to be one of the following tools.

### Deepbinner

Deepbinner: Demultiplexing barcoded Oxford Nanopore Technologies reads with deep convolutional neural networks (CNN). The network is trained to classify barcodes based on the raw nanopore signal. The model for the CNN needs to be copied from the Deepbinner repository to the working directory and depends on the used sequencing kit. The kit is parsed from the run name as described in the [configuration](../installation/configuration.md), alternatively the *default* mapping can be used to override the kit of the run name.

```
deepbinner_models:
    default: SQK-RBK004_read_starts
    EXP-NBD103: EXP-NBD103_read_starts
    SQK-RBK004: SQK-RBK004_read_starts
```

### Guppy

The basecaller from ONT also contains a demultiplexing software. In contrast to Deepbinner, guppy barcoding requires basecalling of all reads and detects barcodes in the sequence. The guppy barcoder can be combined with any basecaller specified as 'demux_seq_workflow' in the *nanopype.yaml*. The 'demux_seq_tag' describes the target tag after demultiplexing. To avoid re-basecalling, Nanopype will copy the reads belonging to every barcode to the respective tag output directory.

```
demux_seq_workflow : 'guppy'
demux_seq_tag : 'WA01.fast'
demux_guppy_kits : 'EXP-NBD103 EXP-NBD104'
```

With the above config the following command will basecall the entire run once and merge reads from barcode NB01:

```
snakemake --snakefile ~/nanopype/Snakefile sequences/guppy/WA01.fast.NB01.fastq.gz
```

While the following will first basecall the entire run with guppy, detect barcodes and re-basecall all reads from barcode NB01:

```
snakemake --snakefile ~/nanopype/Snakefile sequences/guppy/WA01.hac.NB01.fastq.gz
```

This behavior can be useful to detect barcodes using the guppy fast config and only re-basecall a single barcode with the high accuracy model after changing the configuration in *nanopype.yaml*.

## References

> Wick, R. R., Judd, L. M. & Holt, K. E. Deepbinner: Demultiplexing barcoded Oxford Nanopore reads with deep convolutional neural networks. PLOS Computational Biology 14, e1006583 (2018).
