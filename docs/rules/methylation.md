# Methylation

Nanopore sequencing enables the simultaneous readout of sequence and base modification status on single molecule level. Nanopype currently integrates nanopolish and flappie to detect 5mC DNA methylation. To obtain the methylation readout of a single Flow-Cell using nanopolish run:  

    snakemake --snakefile /path/to/nanopype/Snakefile methylation/nanopolish.5x.hg38.bedGraph

or

    snakemake --snakefile /path/to/nanopype/Snakefile methylation/nanopolish.5x.hg38.bw

If not already present, this will trigger basecalling and alignment of the raw data. Similar to the basecalling and alignment modules a *runnames.txt* in the working directory is required. Furthermore only CpGs with at least 5x coverage are reported. The *5x* in the commands file name is an arbitrary tag, the minimum coverage is set in the config.yaml:

:   * methylation_min_coverage: 1

## Folder structure

```sh
|--/methylation/
   |--nanopolish/                                                 # Nanopolish
      |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
         |--0.hg38.tsv                                            # Single read batches
         |--1.hg38.tsv
          ...
      |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.tsv.gz
   |--nanopolish.1x.hg38.bedGraph                                 # Mean methylation level
   |--nanopolish.1x.hg38.bw
   |--flappie/                                                    # Flappie
      |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
         |--0.hg38.tsv                                            # Single read batches
         |--1.hg38.tsv
   |--flappie.1x.hg38.bedGraph
   |--flappie.1x.hg38.bw
```

*Note:* The output from Flappie is under development and not available in the current release.

## Tools

The output of nanopore methylation calling tools on a lower level is not consistent. Here we provide the description of the intermediate results, enabling more advanced analysis.

### Nanopolish

The bed-like intermediate output file contains per read and CpG methylation log-likelihood ratios as well as the raw log-p values from the nanopolish HMM.

    chr6	31164635	31164635	2975d04a-9890-43cd-880b-28a1d72b0f19	2.31    +	-146.60	-148.91

A log-likelihood ratio greater 2.5 is considered a methylated CpG, a ratio less than -2.5 is called unmethylated. To get genome wide mean methylation levels in bedGraph or BigWig format you can use:

To directly get the single read methylation levels you can run:

    snakemake --snakefile /path/to/nanopype/Snakefile methylation/nanopolish/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.tsv.gz

Nanopolish specific configuration parameters are:

:   * methylation_nanopolish_logp_threshold: 2.5
    * methylation_nanopolish_basecaller: guppy
    * methylation_nanopolish_aligner: minimap2
    * methylation_min_coverage: 1

Nanopolish only works with basecalling from albacore or guppy.

### Flappie

Flappie is a new ONT neural network basecaller with a default output alphabet of *ACGT*. Using a different model, a methylation status prediction in CpG contexts is possible. A methylated Cytosine is then encoded as *Z*.

The Flappie sequence output is aligned against a reference genome. A CG in the reference with matching CG in the read is reported as unmethylated, a CG in the reference with matching ZG is reported as methylated.
The output is again a bed-like file with the methylation level in the 4th column:

    chr6	31129299	31129301	f56afc41-fc2c-4157-941d-b8416eb11d2c	0	+

## References

> Simpson, Jared T. et al. Detecting DNA cytosine methylation using nanopore sequencing. Nature Methods 14.4, 407-410 (2017).
