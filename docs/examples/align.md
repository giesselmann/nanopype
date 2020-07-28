# Alignment

This tutorial covers the basic steps to align Oxford Nanopore Technologies data using Nanopype. Common alignment algorithms work in sequence space and depend on previously base called reads. Different combinations of base caller and aligner are supported and may be utilized depending on the intended analysis.

Before starting a first alignment, a reference sequence is required. The given test data is either from a lambda phage run (DNA) or a subset of transcripts covering DNMT1 (cDNA and mRNA). The download in the introduction contains reference sequences for both.

The *env.yaml* in the original repository contains the required reference entries for this tutorial:

    references:
        NC_001416_1:
            genome: ref/NC_001416.1.fasta
            chr_sizes: ref/NC_001416.1.sizes
        hg38_DNMT1:
            genome: ref/hg38_DNMT1.fasta
            chr_sizes: ref/hg38_DNMT1.sizes

## Implicit base calling

The easiest way to obtain an alignment is to directly request the output file for a single flow cell with:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 alignments/minimap2/guppy/batches/DNA/20190225_FAH93688_FLO-MIN106_SQK-LSK109_sample.NC_001416_1.bam -n
```

You should see the following job list:

    Job counts:
            count   jobs
            1       aligner_merge_batches
            1       aligner_merge_batches_names
            1       aligner_sam2bam
            1       guppy
            1       minimap2
            5

Restart the command without the dry-run flag! This will trigger base calling using guppy and an alignment against the NC_001416_1 genome with minimap2. Inspect the alignments output directory to verify, that the requested bam file is there.
In order to process multiple runs in parallel and merge the results into a single output file, a **runnames.txt** in the working directory is used:

```
echo '20190225_FAH93688_FLO-MIN106_SQK-LSK109_sample' > runnames.txt
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 alignments/minimap2/guppy/DNA.NC_001416_1.bam -n
```

Note that Snakemake detects the basecalled and aligned batch from the previous run. Only jobs merging bam files are listed:

    Job counts:
            count   jobs
            1       aligner_merge_batches_names
            1       aligner_merge_tag
            1       aligner_merge_tag_names
            3

Re-run the command without the dry-run flag.


## Explicit base calling

Often you may already have base called data and want to run only the alignment. Nanopype will detect existing sequence data in fastq.gz format and use them as input. For this example we will first run the base calling with a different tag (DNA2 instead of DNA) and manually start the alignment -this time with graphmap2- afterwards:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 sequences/guppy/DNA2.fastq.gz
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 alignments/graphmap2/guppy/DNA2.NC_001416_1.bam -n
```

    Job counts:
            count   jobs
            1       aligner_merge_batches_names
            1       aligner_merge_tag
            1       aligner_merge_tag_names
            1       aligner_sam2bam
            1       graphmap2
            1       graphmap_index
            6

Note that the second command only contains jobs running the alignment. In contrast to minimap2, graphmap2 needs to index the reference genome beforehand. This is handled automatically by Nanopype. As before, execute snakemake without the dry-run flag.


## Batch processing

Browsing the working directory after this tutorial you will notice the batch output in form of e.g. *batch0.fastq.gz* or *batch0.NC_001416_1.bam* in a specific **batches** folder. These files are temporary and can be deleted after the processing. They are however required as input for the processing, thus if you delete the sequence batches a subsequent alignment run will include base calling to get the batch-wise input.
