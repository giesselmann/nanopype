# Structural Variations

Nanopore sequencing is especially suitable to resolve structural variations including insertions, deletions, duplications, inversions, and translocations. The output of the structural variations module of nanopype is a vcf file for further downstream processing. To run e.g. Sniffles on the ngmlr alignment output of multiple Flow-Cells specified in a *runnames.txt* execute:

    snakemake --snakefile /path/to/nanopype/Snakefile WA01.ngmlr.hg38.sniffles.vcf

The SV module includes the following tools:

### sniffles

Sniffles is reported to work best with the NGMLR aligner also included in this pipeline. It is therefore recommended but not mandatory to use the example command in connection with sniffles.

### References

> Sedlazeck, F. J. et al. Accurate detection of complex structural variations using single-molecule sequencing. Nature Methods 15, 461-468 (2018).
