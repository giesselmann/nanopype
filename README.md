# nanopype 

[![Docker Automated build](https://img.shields.io/docker/automated/giesselmann/nanopype.svg)](https://hub.docker.com/r/giesselmann/nanopype/) [![Read the Docs (version)](https://img.shields.io/readthedocs/nanopype/development.svg)](https://nanopype.readthedocs.io/en/development/)

Nanopype is a snakemake based pipeline providing convinient nanopore data processing and storage solutions.
	
## Concepts

**Modularization**

Nanopype is based on the snakemake framework providing rules to execute nanopore bioinformatic applications and chaining them into common workflows. Uniform interfaces of related tools allow easy exchange and extension of the pipeline components.

**Scalability**

Increased throughput and decreasing costs require efficient parallel processing of nanopore long read datasets. Nanopype was developed with focus on batch processing of dataset fractions improving performance on heterogeneous cluster environments.

**Automation**

Applying the output from input file(s) driven workflow design of snakemake with recurring directory structures simplifies a high degree of automation in the data processing. Nanopype furthermore provides scripts and concepts to import and organize datasets from the sequencer.

## Quick start

Install nanopype into an existing python3 installation from [github.com](https://github.com/giesselmann/nanopype/) 

    git clone https://github.com/giesselmann/nanopype
    cd nanopype
    pip3 install -r requirements.txt

or use automated Docker builds from [hub.docker.com](https://hub.docker.com/r/giesselmann/nanopype/).

    docker pull giesselmann/nanopype
    docker run -it giesselmann/nanopype

Snakemake is controlled by requesting output files from existing inputs. To obtain for instance a complete basecalling and alignment you just have to run

    snakemake [OPTIONS...] alignments/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.minimap2.hg19.bam
    
to trigger basecalling and minimap2 alignment against the hg19 reference genome. Snakemake will create a graph containing all intermediate results and execute required rules in respective order.
