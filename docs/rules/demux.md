# Demultiplexing

With barcoded libraries nanopore sequencing allows to pool multiple samples on a single Flow-Cell. Demultiplexing describes the classification of barcodes per read and the assignment of read groups. The output of the demultiplexing module is a tsv file of read ID and detected barcode. In order to process a barcoded Flow-Cell with e.g. Deepbinner run:

    snakemake --snakefile /path/to/nanopype/Snakefile demux/20180101_FAH12345_FLO-MIN106_SQK-RBK004_WA01.deepbinner.tsv
    
Note the different sequencing kit *SQK-RBK004* used in this example. The demultiplexing module includes the following tools and their respective configuration:

### albacore

The ONT basecaller directly supports demultiplexing in sequence space.

    basecalling_albacore_barcoding: true

### deepbinner

Deepbinner: Demultiplexing barcoded Oxford Nanopore reads with deep convolutional neural networks. The network is trained to classify barcodes based on the raw nanopore signal. The model for the NN needs to be copied from the Deepbinner repository to the working directory and depends on the used sequencing kit. The kit is parsed from the runname as described in the [configuration](../configuration.md).

    threads_demux: 4
    deepbinner_models:
        default: SQK-RBK004_read_starts
        EXP-NBD103: EXP-NBD103_read_starts
        SQK-RBK004: SQK-RBK004_read_starts
        
### References

> Wick, R. R., Judd, L. M. & Holt, K. E. Deepbinner: Demultiplexing barcoded Oxford Nanopore reads with deep convolutional neural networks. PLOS Computational Biology 14, e1006583 (2018).
