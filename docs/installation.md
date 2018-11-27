# Installation

## Docker
Run nanopype with all its dependencies from within an automated built docker container. This is primarily for local usage and does currently not support snakemakes cluster engine. 

    docker pull giesselmann/nanopype


## Python
Install nanopype into an existing python3 installation from [github.com/giesselmann](https://github.com/giesselmann/nanopype/):

    git clone https://github.com/giesselmann/nanopype
    cd nanopype
    pip3 install -r requirements.txt
	

## Tools
Nanopype integrates a variety of different tools merged into processing pipelines for common use cases. If you don't use the docker image, you will need to install them separately and tell nanopype via the environment [configuration](configuration.md) where to find them. The Dockerfile in the [github](https://github.com/giesselmann/nanopype/) repository can be used as a detailed guide.

Currently the following tools are available:

**Basecalling**

:   * Albacore (access restricted to ONT community)

**Alignment**

:   * Minimap2 *https://github.com/lh3/minimap2*
    * Graphmap *https://github.com/isovic/graphmap*
    * Ngmlr *https://github.com/philres/ngmlr*
    
**Methylation detection**

:   * Nanopolish *https://github.com/jts/nanopolish*

**Structural variation**

:   * Sniffles *https://github.com/fritzsedlazeck/Sniffles*

**Miscellaneous**

:   * Samtools *https://github.com/samtools/samtools*
    * Bedtools *https://github.com/arq5x/bedtools2*
    * UCSCTools *http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/*
        * bedGraphToBigWig 

