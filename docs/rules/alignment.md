# Alignment

The alignment step maps basecalled reads against a reference genome. If not already done alignment rules will trigger basecalling of the raw nanopore reads.

To align the reads of one Flow-Cell against reference genome hg38 with default basecalling and aligner *minimap2* run from within your processing directory:

    snakemake --snakefile /path/to/nanopype/Snakefile alignments/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.minimap2.hg38.bam
    
This requires an entry *hg38* in your **env.yaml** in the nanopype installation directory:

    references:
        hg38:
            genome: /path/to/references/hg38/hg38.fa
            chr_sizes: /path/to/references/hg38/hg38.chrom.sizes
            
Providing a *runnames.txt* with one runname per line it is possible to process multiple Flow-Cells at once and merge the output into a single track e.g.:

    snakemake --snakefile /path/to/nanopype/Snakefile WA01.minimap2.hg38.bam

The default basecaller for alignments can be configured in the **config.yaml** of the working directory. Depending on the application you can choose from one of the listed aligners. All alignment rules share a set of global config variables:

    threads_alignment: 3
    alignment_default_basecaller: albacore
    
An alignment job is always connected with a sam2bam conversion and sorting in an additonal thread. The above commands with 3 configured alignment threads will therefore fail if snakemake is invoked with less than 4 threads (at least *-j 4* is required). The default input sequence format for alignment rules is *fastq*, yet if possible, the alignment module will use already basecalled batches in the sequences/[runname]/ folder of the working directory.

### minimap2

Pairwise alignment for nucleotide sequences

    alignment_minimap2_flags: '-ax map-ont -L'

### graphmap

Fast and sensitive mapping of nanopore sequencing reads with GraphMap

    alignment_graphmap_flags: '-B 100'
    
### ngmlr

Accurate detection of complex structural variations using single-molecule sequencing

    alignment_ngmlr_flags: '-x ont --bam-fix'


### References

>Li, H. Minimap2: pairwise alignment for nucleotide sequences. Bioinformatics. doi:10.1093/bioinformatics/bty191 (2018).
 
>Sovic, I. et al. Fast and sensitive mapping of nanopore sequencing reads with GraphMap. Nat. Commun. 7:11307 doi: 10.1038/ncomms11307 (2016).
 
>Sedlazeck, F. J. et al. Accurate detection of complex structural variations using single-molecule sequencing. Nature Methods 15, 461-468 (2018).