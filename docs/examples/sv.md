# Structural Variation

This tutorial covers the basic steps to call structural variations in vcf format from long reads. In the previous sections you learned the basics about basecalling and alignment with Nanopype works. The sv module is placed downstream of the alignments supporting a variety of basecalling into alignment into sv workflows.

Structural variation detection is designed to support pooling of multiple flow cells. In this example we have only reads from one, still a **runnames.txt** is needed in the working directory:

```
echo '20190225_FAH93688_FLO-MIN106_SQK-LSK109_sample' > runnames.txt
```

To start SVIM with guppy basecalling and minimap2 alignment, simply run the following command:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 sv/svim/minimap2/guppy/DNA.NC_001416_1.vcf.gz -n
```

Depending on if you already ran the alignment tutorial, the job list is different, either:

    Job counts:
            count   jobs
            1       sv_compress
            1       svim
            2

or:

    Job counts:
            count   jobs
            1       aligner_merge_batches_names
            1       aligner_merge_tag
            1       aligner_merge_tag_names
            1       aligner_sam2bam
            1       guppy
            1       minimap2
            1       sv_compress
            1       svim
            8

Snakmake will always reuse intermediate results found in the processing directory. It is therefore highly recommended to keep the temporary output in the *batches* folders of each module until the entire workflow is completed.

Execute the sv detection without the dry-run flag:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 sv/svim/minimap2/guppy/DNA.NC_001416_1.vcf.gz
```

***

Of course any combination of basecalling, alignment and sv detection is possible:

```
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 sv/sniffles/ngmlr/guppy/DNA.NC_001416_1.vcf.gz -n
snakemake --snakefile ~/src/nanopype/Snakefile -j 4 sv/sniffles/minimap2/guppy/DNA.NC_001416_1.vcf.gz -n
```

Note again the different jobs required (new NGRML alignment):

    Job counts:
            count   jobs
            1       aligner_merge_batches_names
            1       aligner_merge_tag
            1       aligner_merge_tag_names
            1       aligner_sam2bam
            1       ngmlr
            1       sniffles
            1       sv_compress
            7

vs (existing minimap2 alignment):

    Job counts:
            count   jobs
            1       sniffles
            1       sv_compress
            2

Done! All examples of this tutorial produced vcf.gz files for further downstream analysis. Using SVIM for instance, filtering the output by score is a good next step.
