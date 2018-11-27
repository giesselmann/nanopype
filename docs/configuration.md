# Configuration

Nanopype has two configuration layers: The installation bound central environment configuration covers tool paths and reference genomes. The environment configuration is stored in the installation directory. For a project an additional workflow configuration is required providing data sources, tool flags and parameters. The workflow config is stored in the root of each project directory.

All configuration files are in .yaml format.

## Environment

The default environment configuration **env.yaml** assumes all required tools to be available through your systems PATH variable. To use nanopype with existing installations you may need to adjust their paths. Each tools is configured as key:value pair of tool name and the executable. 

```
bin:
    # tool is in PATH variable
    albacore: read_fast5_basecaller.py
    # tool is not in PATH variable
    bedtools: /src/bedtools2/bin/bedtools
```

In order to execute workflows containing alignment steps, the respective reference genomes need to be set up. Each reference is provided as a key (e.g. mm9, mm10, hg19, ..), the genome in fasta format and optionally a chromosome size file if using tools such as *bedGraphToBigWig*.
```
references:
    mm9:
        genome: /path/to/mm9/mm9.fa
        chr_sizes: /path/to/mm9/mm9.chrom.sizes
        
```

## Workflow



## Cluster
