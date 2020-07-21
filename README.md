# Nanopype

[![Latest GitHub release](https://img.shields.io/github/release/giesselmann/nanopype.svg)](https://github.com/giesselmann/nanopype/releases/latest) [![Build Status](https://travis-ci.org/giesselmann/nanopype.svg?branch=master)](https://travis-ci.org/giesselmann/nanopype) [![Read the Docs (version)](https://img.shields.io/readthedocs/nanopype/latest.svg)](https://nanopype.readthedocs.io/en/latest/)

## Documentation

<img align="right" src="https://github.com/giesselmann/nanopype/blob/master/docs/images/workflow.png" width="30%" hspace="20">

Detailed documentation and tutorials are available at [readthedocs](https://nanopype.readthedocs.io/en/latest/).

Nanopype is a snakemake based pipeline providing convenient Oxford Nanopore Technology (ONT) data processing and storage solutions.

The pipeline is split in a *processing* part including basecalling and alignment and an *analysis* part covering further downstream applications.
A summary of all included tools is given in the **[tools](https://nanopype.readthedocs.io/en/latest/tools/)** section.

To get started the **[installation](https://nanopype.readthedocs.io/en/latest/installation/prerequisites/)** chapter describes the available installation options depending on the operation system, available hardware and already existing environments.

Recurring steps of the nanopore data analysis are covered under **[workflow](https://nanopype.readthedocs.io/en/latest/usage/general/)** for both local and cluster usage.

The **modules** part covers an in depth description of all available tools and workflows together with their respective configuration options. This section is the main reference of the pipeline.

Finally for new users the **[tutorial](https://nanopype.readthedocs.io/en/latest/examples/intro/)** might be helpful to learn the general concepts and usage of the pipeline. To complete the tutorial the test reads included in the package are sufficient and no separate wet-lab experiemnt is required.
