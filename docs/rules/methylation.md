# Methylation

Nanopore sequencing enables the simultaneous readout of sequence and base modification status on single molecule level. Nanopype currently integrates nanopolish and flappie to detect 5mC DNA methylation. To obtain the methylation readout of multiple flow cells using nanopolish run:  

    snakemake --snakefile /path/to/nanopype/Snakefile methylation/nanopolish/ngmlr/albacore/WA01.5x.hg38.bedGraph

or

    snakemake --snakefile /path/to/nanopype/Snakefile methylation/nanopolish/ngmlr/albacore/WA01.5x.hg38.bw

If not already present, this will trigger basecalling and alignment of the raw data. Similar to the basecalling and alignment modules a *runnames.txt* in the working directory is required. Furthermore only CpGs with at least 5x coverage are reported. The coverage wildcard can be any positive integer in combination with arbitrary text (e.g. *5*, *5x* or *min5x* will result in the same output).

## Folder structure

```sh
|--methylation/
   |--nanopolish/                                                 # Nanopolish
      |--ngmlr/                                                   # NGMLR alignment
         |--guppy/                                                # Guppy sequences
            |--batches/
               |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
                  |--0.hg38.tsv                                   # Single read batches
                  |--1.hg38.tsv
                   ...
            |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.tsv.gz
            |--WA01.1x.hg38.bedGraph                              # Mean methylation level
            |--WA01.1x.hg38.bw
   |--flappie/                                                    # Flappie
      |--ngmlr/
         |--flappie/
            |--batches/
               |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
                  |--0.hg38.tsv                                   # Single read batches
                  |--1.hg38.tsv
            |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.tsv.gz
            |--WA01.1x.hg38.bedGraph
            |--WA01.1x.hg38.bw
```


## Tools

The output of nanopore methylation calling tools on a lower level is not consistent. Here we provide the description of the intermediate results, enabling more advanced analysis. All methylation rules share a set of global config variables:

:   * threads_methylation: 3

### Nanopolish

The bed-like intermediate output file contains per read and CpG methylation log-likelihood ratios as well as the raw log-p values from the nanopolish HMM.

    chr6	31164635	31164635	2975d04a-9890-43cd-880b-28a1d72b0f19	2.31    +	-146.60	-148.91

A log-likelihood ratio greater 2.5 is considered a methylated CpG, a ratio less than -2.5 is called unmethylated. To get genome wide mean methylation levels in bedGraph or BigWig format you can use:

To directly get the single read methylation levels of a single flow cell you can run:

    snakemake --snakefile /path/to/nanopype/Snakefile methylation/nanopolish/ngmlr/guppy/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.tsv.gz

Nanopolish specific configuration parameters are:

:   * methylation_nanopolish_logp_threshold: 2.5

### Flappie

Flappie is a new ONT neural network basecaller with a default output alphabet of *ACGT*. Using a different model, a methylation status prediction in CpG contexts is possible. A methylated Cytosine is then encoded as *Z*.

The Flappie sequence output is aligned against a reference genome. A CG in the reference with matching CG in the read is reported as unmethylated, a CG in the reference with matching ZG is reported as methylated.
The single read output is again a bed-like file with the methylation level in the 4th column and the mean q-val over the CG in the 6th column:

    chr6	31129299	31129301	f56afc41-fc2c-4157-941d-b8416eb11d2c	0	+	5.0

Flappie specific configuration parameters are:

:   * basecalling_flappie_model: 'r941_5mC'
    * methylation_flappie_qval_threshold: 3

## References

> Simpson, Jared T. et al. Detecting DNA cytosine methylation using nanopore sequencing. Nature Methods 14.4, 407-410 (2017).
