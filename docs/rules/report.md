# Report

The automatic generation of a pdf-report is the last step in the processing provided by Nanopype. In contrast to all other modules, the report does not trigger any processing and only summarizes, what's present in the current working directory.

Nonetheless it's recommended to check the processing with a dry-run before:

```
snakemake --snakefile /path/to/nanopype/Snakefile report.pdf -n
snakemake --snakefile /path/to/nanopype/Snakefile report.pdf -j 8
```


The report module will create a folder *report* with plots in svg and pandas data tables in hdf5 format. After additional processing steps, you can force a re-run of report specific rules by using e.g.:

```
snakemake --snakefile /path/to/nanopype/Snakefile report.pdf -j 8 --force -n
```


The generated pdf-report is a dynamic document with sections for the different modules of the pipeline. Currently the following outputs are considered:

:   * Flow cells:
        * configured flow cells
        * disk usage summary of raw and processing directories
    * Sequences:
        * Read length and cumulative throughput for each basecaller and tag.
        * Throughput and length distribution per flow cell
    * Alignments:
        * Mapped read counts
        * Mapped bases
        * coverage track
    * Methylation:
        * Number of CpGs depending on coverage threshold

An example pdf report of three MinION flow cells is given below:

<object data="https://raw.githubusercontent.com/giesselmann/nanopype/master/docs/report.pdf" type="application/pdf" width="700px" height="700px">
    <embed src="https://raw.githubusercontent.com/giesselmann/nanopype/master/docs/report.pdf">
        <p>This browser does not support PDFs. Please download the PDF to view it: <a href="https://raw.githubusercontent.com/giesselmann/nanopype/master/docs/report.pdf">Download PDF</a>.</p>
    </embed>
</object>
