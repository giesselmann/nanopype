# Alignment

This tutorial covers the basic steps to align Oxford Nanopore Technologies data using Nanopype. Common alignment algorithms work in sequence space and depend on previously base called reads. Different combinations of base caller and aligner are supported and may be utilized depending on the intended analysis.

Before starting a first alignment, a reference sequence is required. The given test data is extracted from a region on human chr6 which we will download into a reference folder in the current working directory:

```
mkdir -p references
wget -O references/chr6.fa.gz http://hgdownload.cse.ucsc.edu/goldenpath/hg38/chromosomes/chr6.fa.gz
gzip -d references/chr6.fa.gz
```

The *env.yaml* in the original repository already contains an entry for this tutorial:

    references:
        test:
            genome: references/chr6.fa

## Implicit base calling

The easiest way to obtain an alignment is to directly request the output file with:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 alignments/minimap2/guppy/runs/20170725_FAH14126_FLO-MIN107_SQK-LSK308_human_Hues64.test.bam
```

This will trigger base calling using guppy and an alignment against our test genome with minimap2. In order to process multiple runs in parallel and merge the results into a single output file, a runnames.txt in the working directory is used:

```
for d in data/raw/*; do echo $(basename $d); done > runnames.txt
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 alignments/minimap2/guppy/tutorial.test.bam
```

Snakemake will automatically detect the already present output from flow cell *FAH14126* and start processing the remaining datasets from the runnames.txt file.


## Explicit base calling

Often you may already have base called data and want to run only the alignment. Nanopype will detect existing sequence data in fasta and fastq format and use them as input. For this example we will first run the base calling with a different tool and manually start the alignment afterwards:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 sequences/albacore/tutorial.fa.gz
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 alignments/minimap2/albacore/tutorial.test.bam
```

Note that the second command only contains jobs running minimap2.


## Batch processing

Browsing the working directory after this tutorial you will notice the batch output in form of e.g. *0.fastq.gz* or *0.test.bam* in a specific run folder. These files are temporary and can be deleted after the processing. They are however required as input for the processing, thus if you delete the sequence batches a subsequent alignment run will include base calling to get the batch-wise input.

We will target this issue in a future release of Nanopype. The merged fastx filex can be split according to the read name and merged bam files already contain a RG tag with the source batch.
