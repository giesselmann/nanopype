# Installation

*Important*: If you encounter any trouble within the installation, open an issue on [github](https://github.com/giesselmann/nanopype/issues) to make others aware of the problem or write an E-Mail to ```giesselmann[at]molgen.mpg.de```. There is nothing more annoying than software that does not work.

In general snakemake and thus also Nanopype is python based and therefore available on Windows, MacOS and Linux. However the included bioinformatic tools are often only available for Linux like operating systems. We support and test the fully featured pipeline on Linux and MacOS and through containerization enable reduced functionality on Windows.

??? info "Docker & Singularity container"
    Docker and Singularity provide encapsulation of software environments into so-called *"containers"*. A docker-image can e.g. based on Ubuntu contain the basecaller *flappie* with all of its dependencies and without further installation be executed on any operating system with just Docker installed.
    Singularity can handle both Docker and Singularity images and is supported by snakemake allowing the execution of workflows in isolated environments.
    

We provide singularity images per module, wrapper to build and install tools from source and a single stand-alone Docker image of the entire pipeline. Depending on operating system, required functionality and experience one the following methods should be selected:

<center>

| Method   	| Singularity 	| Source 	| Docker 	|
|---------	|:-----------:	|:------:	|:------:	|
| Linux   	|     yes     	|   yes  	|   yes  	|
| MacOS   	|     yes     	|   yes  	|   yes  	|
| Windows 	|      no     	|   no   	|   yes  	|
| Tools   	|     all     	|   all  	| public[^1]|
| Cluster   |     yes       |   yes     |   no      |
| Complexity|     low       | high      | low       |


</center>

Rrecommendation: If possible use the singularity workflow of Nanopype. If you have already existing installations or wish to customize or optimize the build process go for the source installation. If you want to quickly test or run the pipeline on a Windows machine use the all-in-one Docker container.

!!! warning "Configuration"
    Independant of the installation the pipeline needs to be configured once [globaly](configuration.md) and for each sample [locally](../usage/general.md).

[^1]: Some tools provided by Oxford Nanopore are only available through the ONT-community for users with access. After manual installation these are supported by nanopype but cannot be distributed in Docker images.

