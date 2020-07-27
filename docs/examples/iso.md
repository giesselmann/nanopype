# Isoform Detection

Another readout from Oxford Nanopore long read sequencing is the detection of RNA isoforms from full-length transcripts. Different protocols for either direct RNA or cDNA demand different configurations of the pipeline. While the default config of Nanopype is suitable for all kinds of DNA sequencing runs, this tutorial shows how to run the pipeline with adjusted parameters.

Please note that the illustrated workflows are considered to be a first step and may require more sophisticated downstream processing and filtering.

## cDNA sequencing

The example data includes both, reads from direct RNA and cDNA sequencing. To start with the latter, add the respective run name to the **runnames.txt** in the working directory:

```
echo '20200624_FAN48644_FLO-MIN106_SQK-DCS109_sample' > runnames.txt
```

Raw data from cDNA sequencing can be processed with default basecaller settings but requires different flags for the alignment. With your favorite text editor verify and update the following entries of the **nanopype.yaml**:

    basecalling_guppy_config: 'dna_r9.4.1_450bps_fast.cfg'
    alignment_samtools_flags: '-F 2308'
    alignment_minimap2_flags: '-ax splice'
    transcript_cluster_gff_flags: '-c 1'

Alignments need to be filtered for mapped reads only, minimap2 is running in splice mode and due to the low coverage of the example data, we report every consensus sequence, even if only supported by a single read.

Isoforms detected by the pinfish workflow are reported in gff format:
```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 transcript_isoforms/pinfish/minimap2/guppy/cDNA.hg38_DNMT1.gff -n
```

The list of jobs to run should look like this:

    Job counts:
            count   jobs
            1       aligner_merge_batches_names
            1       aligner_merge_tag
            1       aligner_merge_tag_names
            1       aligner_sam2bam
            1       guppy
            1       minimap2
            1       pinfish
            7

This tutorial uses a different *tag* than the previous ones (cDNA instead of DNA). This mechanism is used to separate the results from different configuration values within the same working directory.

Execute the workflow without the dry-run flag...


## direct RNA sequencing

To proceed with the processing of direct RNA reads, change the run names as follows (Note the different sequencing kit indicated in the run name):

```
echo '20200227_FAL08241_FLO-MIN106_SQK-RNA002_sample' > runnames.txt
```

Adjust the configuration in **nanopype.yaml** to:

    basecalling_guppy_config: 'rna_r9.4.1_70bps_fast.cfg'
    alignment_samtools_flags: '-F 2308'
    alignment_minimap2_flags: '-ax splice'
    transcript_cluster_gff_flags: '-c 1'

Note the different basecall config and reduced sequencing speed for direct RNA. Again we use a different *tag* to avoid confusion with the previously computed output:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 transcript_isoforms/pinfish/minimap2/guppy/mRNA.hg38_DNMT1.gff -n
```

results in new basecalling, alignment and isoform detection:

    Job counts:
            count   jobs
            1       aligner_merge_batches_names
            1       aligner_merge_tag
            1       aligner_merge_tag_names
            1       aligner_sam2bam
            1       guppy
            1       minimap2
            1       pinfish
            7


Done! This tutorial showed you basic steps to handle both, cDNA and direct RNA data from ONT sequencers.
