# Methylation

Nanopore sequencing enables the simultaneous readout of sequence and base modification status on single molecule level. Nanopype currently integrates the nanopolish pipeline to detect 5mC DNA methylation. To obtain the methylation readout of a single Flow-Cell run:

    snakemake --snakefile /path/to/nanopype/Snakefile methylation/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.nanopolish.hg38.tsv
    
If not already present, this will trigger basecalling and alignment of the raw data. The bed-like output file contains per read and CpG methylation log-likelihood ratios as well as the raw log-p values from the nanopolish HMM.

    chr6	31164635	31164635	2975d04a-9890-43cd-880b-28a1d72b0f19	2.31	-146.60	-148.91

A log-likelihood ratio greater 2.5 is considered a methylated CpG, a ratio less than -2.5 is called unmethylated. To get genome wide mean methylation levels in bedGraph or BigWig format you can use:
    
    snakemake --snakefile /path/to/nanopype/Snakefile WA01.5x.hg38.bw
    
Similar to the basecalling and alignment modules this requires a *runnames.txt* in the working directory and will process multiple Flow-Cells at once. Furthermore only CpGs with at least 5x coverage are reported. The *5x* in the commands file name is an arbitrary tag, the minimum coverage, used aligner and log-p threshold are set in the config.yaml:

    methylation_nanopolish_logp_threshold: 2.5
    methylation_nanopolish_aligner: graphmap
    methylation_min_coverage: 1
    
    
### References

> Simpson, Jared T. et al. Detecting DNA cytosine methylation using nanopore sequencing. Nature Methods 14.4, 407-410 (2017).