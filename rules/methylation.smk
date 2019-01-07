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
# imports
import os
from rules.utils.get_file import get_batches, get_sequence_batch, get_alignment_batch
# local rules
localrules: nanopolish_methylation_merge_run, nanopolish_methylation_compress, nanopolish_methylation_bedGraph, nanopolish_methylation_frequencies, methylation_bigwig
# local config
config['bin']['methylation_flappie'] = os.path.abspath(os.path.join(workflow.basedir, 'rules/utils/methylation_flappie.py'))

# get batches
def get_batches_methylation(wildcards, methylation_caller):
    return expand("methylation/{methylation_caller}/{wildcards.runname}/{{batch}}.{wildcards.reference}.tsv".format(wildcards=wildcards, methylation_caller=methylation_caller), batch=get_batches(wildcards, config=config))


# nanopolish methylation detection
rule nanopolish_methylation:
    input:
        signals = "{data_raw}/{{runname}}/reads/{{batch}}.tar".format(data_raw = config["storage_data_raw"]),
        sequences = lambda wildcards ,config=config : get_sequence_batch(wildcards, config, force_basecaller=config['methylation_nanopolish_basecaller']),
        bam = lambda wildcards, config=config : get_alignment_batch(wildcards, config, force_basecaller=config['methylation_nanopolish_basecaller'], force_aligner=config["methylation_nanopolish_aligner"]),
        bai = lambda wildcards, config=config : get_alignment_batch(wildcards, config, force_basecaller=config['methylation_nanopolish_basecaller'], force_aligner=config["methylation_nanopolish_aligner"]) + '.bai'
    output:
        "methylation/nanopolish/{runname, [^./]*}/{batch, [0-9]+}.{reference, [^./]*}.tsv"
    shadow: "minimal"
    threads: config['threads_methylation']
    params:
        reference = lambda wildcards: os.path.abspath(config['references'][wildcards.reference]['genome'])
    resources:
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, input, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    shell:
        """
        mkdir -p raw
        tar -C raw/ -xf {input.signals}
        echo {input.sequences}
        zcat {input.sequences} > sequences.fasta
        {config[bin][nanopolish]} index -d raw/ sequences.fasta
        {config[bin][nanopolish]} call-methylation -t {threads} -r sequences.fasta -g {params.reference} -b {input.bam} > {output}
        """

# merge batch tsv files and split connected CpGs
rule nanopolish_methylation_merge_run:
    input:
        lambda wildcards: get_batches_methylation(wildcards, 'nanopolish')
    output:
        "methylation/nanopolish/{runname, [^./]*}.{reference, [^./]*}.tsv"
    run:
        from rules.utils.methylation_nanopolish import tsvParser
        recordIterator = tsvParser()
        with open(output[0], 'w') as fp_out:
            for ip in input:
                with open(ip, 'r') as fp_in:
                    # skip header
                    next(fp_in)
                    # iterate input
                    for name, chr, strand, sites in recordIterator.records(iter(fp_in)):
                        for begin, end, ratio, log_methylated, log_unmethylated in sites:
                            print('\t'.join([chr, str(begin), str(end), name, str(ratio), strand, str(log_methylated), str(log_unmethylated)]), file=fp_out)

rule nanopolish_methylation_compress:
    input:
        "methylation/{methylation_caller}/{runname}.{reference}.tsv"
    output:
        "methylation/{methylation_caller, [^./]*}/{runname, [^./]*}.{reference, [^./]*}.tsv.gz"
    shell:
        "gzip {input}"

# nanopolish methylation probability to frequencies
rule nanopolish_methylation_frequencies:
    input:
        ['methylation/nanopolish/{runname}.{{reference}}.tsv.gz'.format(runname=runname) for runname in config['runnames']]
    output:
        "methylation/nanopolish.{reference, [^./]*}.frequencies.tsv"
    params:
        log_p_threshold = config['methylation_nanopolish_logp_threshold']
    shell:
        """
        zcat {input} | cut -f1-3,5 | perl -anle 'if(abs($F[3]) > {params.log_p_threshold}){{if($F[3]>{params.log_p_threshold}){{print join("\t", @F[0..2], "1")}}else{{print join("\t", @F[0..2], "0")}}}}' | sort -k1,1 -k2,2n | {config[bin][bedtools]} groupby -g 1,2,3 -c 4 -o mean,count > {output}
        """

# nanopolish frequencies to bedGraph
rule nanopolish_methylation_bedGraph:
    input:
        "methylation/nanopolish.{reference}.frequencies.tsv"
    output:
        "methylation/nanopolish.{coverage, [^./]*}.{reference, [^./]*}.bedGraph"
    shell:
        """
        cat {input} | perl -anle 'print $_ if $F[4] >= {config[methylation_min_coverage]}' | cut -f1-4 > {output}
        """

# bedGraph to bigWig
rule methylation_bigwig:
    input:
        "methylation/{methylation_caller}.{coverage}.{reference}.bedGraph"
    output:
        "methylation/{methylation_caller, [^./]*}.{coverage, [^./]*}.{reference, [^./]*}.bw"
    params:
        chr_sizes = lambda wildcards : config["references"][wildcards.reference]["chr_sizes"]
    shell:
        """
        {config[bin][bedGraphToBigWig]} {input} {params.chr_sizes} {output}
        """
