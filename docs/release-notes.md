# Release notes

#### v0.4.1

Development release:

:   * Update guppy_basecaller to version v2.3.5

#### v0.4.0

Development release:

Version 0.4.0 is the singularity and bulk-fast5 release.

:   * Setup singularity images for each module
    * Support both, .tar of single fast5 and bulk-fast5 of current MinKNOW versions
    * Enhance documentation details on installation and cluster usage

#### v0.3.0

Development release:

The output of nanopype >= v0.3.0 is **not** backwards compatible due to major changes in the output filesystem structure.

:   * Fix guppy installation instructions to not overwrite existing library installations
    * Apply general output structure of *tool2/tool1/runs/runname.x* to all processing chains (see module documentation/tutorial for details).

#### v0.2.1

Development release:

:   * Parse experimental Flappie methylation calls to bedGraph/bigWig
    * Detect bigWig coverage from wildcards without requiring config entry

Known issues:

:   * Installing guppy after flappie is overwriting a symlink to *libhdf5.so* causing the flappie basecaller to load a hdf5 library it was not linked to. This will be fixed in a future release by separating the libraries properly.

#### v0.2.0

Development release:

:   * Nanopolish                v0.11.0
    * htslib                    v1.9
    * OpenBLAS                  v0.3.4

#### v0.1.0

Initial release with tool versions (for development or untagged repositories, the master branch with the tested version in brackets is used):

:   * Bedtools                  v2.27.1
    * Samtools                  v1.9
    * UCSCTools
        * bedGraphToBigWig      v4
    * Flappie                   master (1.1.0-9ef4edf)
    * Minimap2                  v2.14-r883
    * GraphMap                  master (v0.5.2)
    * NGMLR                     v0.2.7
    * Sniffles                  v1.0.10
    * Deepbinner                v0.2.0

Manual installations of *albacore* and *guppy* can't be versioned. The pipeline was tested with albacore 2.3.3 and guppy 2.1.3.
