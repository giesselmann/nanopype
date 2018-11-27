# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : nanopore methylation detection rules
#
#  RESTRICTIONS  : none
#
#  REQUIRES      : none
#
# ---------------------------------------------------------------------------------
# Copyright (c) 2018,  Pay Giesselmann, Max Planck Institute for Molecular Genetics
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Written by Pay Giesselmann
# ---------------------------------------------------------------------------------
localrules: nanopolish_methylation_merge_run, nanopolish_methylation_compress, nanopolish_methylation_bedGraph, nanopolish_methylation_frequencies, methylation_bigwig

# get batches
def get_batches_methylation(wildcards, methylation_caller):
    return expand("methylation/{wildcards.runname}/{{batch}}.{methylation_caller}.{wildcards.reference}.tsv".format(wildcards=wildcards, methylation_caller=methylation_caller), batch=get_batches(wildcards))    


# nanopolish methylation detection
rule nanopolish_methylation:
    input:
        signals = "{data_raw}/{{runname}}/reads/{{batch}}.tar".format(data_raw = config["storage_data_raw"]),
        sequences = "sequences/{runname}/{batch}.albacore.fa",
        bam = "alignments/{{runname}}/{{batch}}.{aligner}.{{reference}}.bam".format(aligner = config["methylation_nanopolish_aligner"]),
        bai = "alignments/{{runname}}/{{batch}}.{aligner}.{{reference}}.bam.bai".format(aligner = config["methylation_nanopolish_aligner"])
    output:
        "methylation/{runname, [^./]*}/{batch, [0-9]+}.nanopolish.{reference, [^./]*}.tsv"
    shadow: "minimal"
    threads: 16
    params:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    shell:
        """
        mkdir -p raw
        tar -C raw/ -xf {input.signals}
        {config[bin][nanopolish]} index -d raw/ {input.sequences}
        {config[bin][nanopolish]} call-methylation -t {threads} -r {input.sequences} -g {params.reference} -b {input.bam} > {output}
        """
 
# merge batch tsv files and split connected CpGs
rule nanopolish_methylation_merge_run:
    input:
        lambda wildcards: get_batches_methylation(wildcards, 'nanopolish')
    output:
        "methylation/{runname, [^./]*}.nanopolish.{reference, [^./]*}.tsv"
    run:
        from scripts.nanopolish import tsvParser
        recordIterator = tsvParser()
        with open(output[0], 'w') as fp_out:
            for ip in input:
                with open(ip, 'r') as fp_in:
                    # skip header
                    next(fp_in)
                    # iterate input
                    for name, chr, sites in recordIterator.records(iter(fp_in)):
                        for begin, end, ratio, log_methylated, log_unmethylated in sites:
                            print('\t'.join([chr, str(begin), str(end), name, str(ratio), str(log_methylated), str(log_unmethylated)]), file=fp_out)

rule nanopolish_methylation_compress:
    input:
        "methylation/{runname}.{methylation_caller}.{reference}.tsv"
    output:
        "methylation/{runname, [^./]*}.{methylation_caller, [^./]*}.{reference, [^./]*}.tsv.gz"
    shell:
        "gzip {input}"

# nanopolish methylation probability to frequencies
rule nanopolish_methylation_frequencies:
    input:
        ['methylation/{runname}.nanopolish.{{reference}}.tsv.gz'.format(runname=runname) for runname in config['runnames']]
    output:
        "{trackname, [^./]*}.nanopolish.{reference, [^./]*}.frequencies.tsv"
    params:
        log_p_threshold = config['methylation_nanopolish_logp_threshold']
    shell:
        """
        zcat {input} | cut -f1-3,5 | perl -anle 'if(abs($F[3]) > {params.log_p_threshold}){{if($F[3]>{params.log_p_threshold}){{print join("\t", @F[0..2], "1")}}else{{print join("\t", @F[0..2], "0")}}}}' | sort -k1,1 -k2,2n | {config[bin][bedtools]} groupby -g 1,2,3 -c 4 -o mean,count > {output}
        """

# nanopolish frequencies to bedGraph
rule nanopolish_methylation_bedGraph:
    input:
        "{trackname}.nanopolish.{reference}.frequencies.tsv"
    output:
        "{trackname, [^./]*}.{coverage, [^./]*}.nanopolish.{reference, [^./]*}.bedGraph"
    shell:
        """
        cat {input} | perl -anle 'print $_ if $F[4] >= {config[methylation_min_coverage]}' | cut -f1-4 > {output}
        """

# bedGraph to bigWig
rule methylation_bigwig:
    input:
        "{trackname}.{coverage}.{methylation_caller}.{reference}.bedGraph"
    output:
        "{trackname, [^./]*}.{coverage, [^./]*}.{methylation_caller, [^./]*}.bw"
    shell:
        """
        {config[bin_dir][ucsctools]}bedGraphToBigWig {input} {config[reference][chr_sizes]} {output}
        """