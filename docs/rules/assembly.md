# Assembly

The assembly module of nanopype provides different tools to directly build consensus sequences from long read sequencing runs.
Assemblies are made from the output of multiple flow-cells with names provided via a *runnames.txt* in the processing directory. The command to assemble contigs with Flye using Guppy for basecalling would be:

    snakemake --snakefile /path/to/nanopype/Snakefile assembly/flye/guppy/WA01.fasta

The tag *WA01* is arbitrary and may describe a corresponding experiment or cell line.

## Folder structure

The assembly module can create the following file structure relative to the working directory:

```sh
|--assembly/
   |--flye/                     # Flye assembler
      |--guppy/                 # Guppy basecalling
         |--WA01/
            |-- ...             # Assembler specific files
         |--WA01.fasta          # Contigs
```


## Cleanup

The assembly module does not have automatic clean up rules at the moment.

## Tools

Depending on the application you can choose from one of the following assemblers, listed with their associated configuration options. All tools share the following configuration options:

```
threads_asm: 80
asm_genome_size : '3.0g'
```

### Flye

Flye is a de novo assembler for single molecule sequencing reads, such as those produced by PacBio and Oxford Nanopore Technologies.

```
asm_flye_preset : '--nano-raw'
asm_flye_flags : '--asm-coverage 35'
```


## References

>Mikhail Kolmogorov, Jeffrey Yuan, Yu Lin and Pavel Pevzner, Assembly of Long Error-Prone Reads Using Repeat Graphs, Nature Biotechnology, 2019 doi:10.1038/s41587-019-0072-8
