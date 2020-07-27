# Structural Variations

Nanopore sequencing is especially suitable to resolve structural variations including insertions, deletions, duplications, inversions, and translocations. The output of the structural variations module of Nanopype is a vcf file for further downstream processing. To run e.g. Sniffles on the NGMLR alignment output of multiple flow cells specified in a *runnames.txt* execute:

    snakemake --snakefile /path/to/nanopype/Snakefile sv/sniffles/ngmlr/guppy/WA01.hg38.vcf

## Folder structure

The structural variation module can create the following file structure relative to the working directory:

```sh
|--/sv/
   |--sniffles/
      |--ngmlr/
         |--guppy/
            |--WA01.hg38.vcf.gz
    |--svim/
       |--minimap2/
          |--guppy/
             |--WA01.hg38.vcf.gz
```

## Cleanup

The structural variation module requires a merged alignment file of one or multiple flow cells. Since most of the pipeline is working with batches of reads, the merged files can be deleted to save disk space:

```sh
|--alignments/
   |--ngmlr/                                                 # NGMLR alignment
      |--guppy/                                              # Using guppy basecalling
         |--batches/
            |--WA01/
               |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/             # keep
                  |--0.hg38.bam                                             # keep
                  |--1.hg38.bam                                             # keep
                  ...
         |--WA01.hg38.bam                                                   # delete
```

## Tools
The SV module includes the following tools:

### Sniffles

Sniffles is reported to work best with the NGMLR aligner also included in this pipeline. It is therefore recommended but not mandatory to use the example command in connection with sniffles. You can further configure the tool by setting any of its command line flags:

:   * sv_sniffles_flags: '-s 10 -l 30 -r 2000 --genotype'

### SVIM

SVIM is an alternative structural variation caller working with both, minimap2 and NGMLR alignments. You can configure SVIM by setting any of its command line flags:

:   * sv_svim_flags: '--min_sv_size 40'

### References

> Sedlazeck, F. J. et al. Accurate detection of complex structural variations using single-molecule sequencing. Nature Methods 15, 461-468 (2018).

>David Heller, Martin Vingron, SVIM: structural variant identification using mapped long reads, Bioinformatics, Volume 35, Issue 17, (2019).
