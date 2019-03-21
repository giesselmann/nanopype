# Transcriptome

Another application of the long-read nanopore technology is sequencing of cDNA and RNA molecules directly. Recovery of full-length transcripts enables, for instance, the detection of alternatively spliced isoforms and is implemented in Nanopype using the Pinfish package. The output of polished transcripts is provided in the GFF format.

## Isoform detection

The isoform detection in Nanopype is oriented to meet the implementation of the [pinfish-pipeline](https://github.com/nanoporetech/pipeline-pinfish-analysis) from ONT, extended by the basecalling and alignment back-end of Nanopype. To align the reads of one flow cell against reference genome hg38 with *guppy* basecalling and aligner *minimap2* and detect isoforms using pinfish run from within your processing directory:

    snakemake --snakefile /path/to/nanopype/Snakefile transcript_isoforms/pinfish/minimap2/guppy/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.gff

This requires an entry *hg38* in your **env.yaml** in the Nanopype installation directory:

    references:
        hg38:
            genome: /path/to/references/hg38/hg38.fa
            chr_sizes: /path/to/references/hg38/hg38.chrom.sizes

Providing a *runnames.txt* with one runname per line it is possible to process multiple flow cells at once and merge the output into a single track e.g.:

    snakemake --snakefile /path/to/nanopype/Snakefile transcript_isoforms/pinfish/minimap2/guppy/WA01.hg38.gff

### Folder structure

The transcript module can create the following example file structure relative to the working directory:

```sh
|--transcript_isoforms
   |--pinfish
      |--alignments/
         |--minimap2/                                                 # Minimap2 alignment
            |--guppy/                                                 # Using guppy basecalling
               |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.hg38.gff
               |--WA01.hg38.gff

```

!!! caution "Alignment"
    The transcript module of Nanopype is generic in terms of used basecaller and aligner. However spliced alignments require a different configuration and are not supported by each incorporated aligner. Nanopype's default configuration values are tuned towards processing of long DNA reads. Please observe the following tools section and set the respective configuration flags in the **nanopype.yaml** in the processing directory.
    Additionally the samtools flags as described below are crucial for the success of the *polish_clusters* past of pinfish.

### Tools

All transcript module rules share a common set of configuration options. The thread option is split for rules processing only batches of reads and rules working on the entire dataset. The latter is expected to profit from more provided cores.

:   * threads_transcript_batch: 4   
    * threads_transcript: 4
    

#### Minimap2

Minimap2 is currently the only incorporated aligner supporting spliced alignments. The program flags depend on the input library. Please also refer to the Minimap2 [repository](https://github.com/lh3/minimap2) for detailed documentation.

:   * alignment_samtools_flags: '-F 2304'
    * alignment_minimap2_flags: '-ax splice'
    * alignment_minimap2_flags: '-ax splice -uf'    # for stranded data
    

#### Pinfish

Pinfish is an ONT package to generate isoform annotations from nanopore RNA sequencing. 

:   * transcript_spliced_bam2gff_flags: ''
    * transcript_cluster_gff_flags: '-c 10 -d 10 -e 30'
    * transcript_collapse_partials: '-d 5 -f 5000 -e 30'
    * transcript_polish_clusters: '-c 10'

## References

>Li, H. Minimap2: pairwise alignment for nucleotide sequences. Bioinformatics. doi:10.1093/bioinformatics/bty191 (2018).

>ONT: Pinfish. https://github.com/nanoporetech/pinfish (2019).