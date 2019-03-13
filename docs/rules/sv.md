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
            |--WA01.hg38.vcf/
```

## Tools
The SV module includes the following tools:

### Sniffles

Sniffles is reported to work best with the NGMLR aligner also included in this pipeline. It is therefore recommended but not mandatory to use the example command in connection with sniffles. You can further configure the tool by setting any of its command line flags:

:   * sv_sniffles_flags: '-s 10 -l 30 -r 2000 --genotype'

### References

> Sedlazeck, F. J. et al. Accurate detection of complex structural variations using single-molecule sequencing. Nature Methods 15, 461-468 (2018).
