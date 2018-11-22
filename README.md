# nanopype
Snakemake pipelines for nanopore sequencing data archiving and processing and analysis

## Installation
### Python

    git clone https://github.com/giesselmann/nanopype
    cd nanopype
	pip3 install -r requirements.txt

### Docker
	git clone https://github.com/giesselmann/nanopype
	cd nanopype
	docker build -t nanopype .

## Configuration

### Environment
Before using nanopype you have to once set up your environment and tell nanopype via the *env.yaml* where to find everything. The environment configuration covers

 - Tools (basecalling, alignment, etc.)
 - Reference genomes
 - ...

### Workflow
Each workflow is configured via a *config.yaml* which needs to be copied to each working directory. The workflow configuration covers

 - Data directories
 - Tool parameters
 - ...

## Usage

