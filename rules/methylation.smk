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
# Copyright (c) 2018-2019, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
import os, re
from rules.utils.get_file import get_batch_ids_raw, get_signal_batch, get_sequence_batch, get_alignment_batch
# local rules
localrules: methylation_nanopolish_merge_run, methylation_nanopolish_frequencies
localrules: methylation_flappie_merge_run, methylation_flappie_frequencies
localrules: methylation_bedGraph, methylation_bigwig, methylation_compress

# get batches
def get_batches_methylation(wildcards, config, methylation_caller):
    r = expand("methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{reference}.tsv",
            methylation_caller=methylation_caller,
            aligner=wildcards.aligner,
            sequence_workflow=wildcards.sequence_workflow,
            tag=wildcards.tag,
            runname=wildcards.runname,
            reference=wildcards.reference,
            batch=get_batch_ids_raw(wildcards.runname, config=config, tag=wildcards.tag, checkpoints=checkpoints))
    return r

def get_batches_methylation2(wildcards, config, methylation_caller):
    r = expand("methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.tsv.gz",
                        methylation_caller=methylation_caller,
                        aligner=wildcards.aligner,
                        sequence_workflow=wildcards.sequence_workflow,
                        tag=wildcards.tag,
                        runname=[runname for runname in config['runnames']],
                        reference=wildcards.reference)
    return r

# parse min coverage from wildcards
def get_min_coverage(wildcards):
    x = [int(s) for s in re.findall(r'\d+', wildcards.coverage) if s.isdigit()]
    if len(x) == 1:
        return x
    else:
        print('Could not parse coverage from wildcard {wildcard}, using default 1x.'.format(wildcard=wildcards.coverage))
        return 1

# nanopolish methylation detection
rule methylation_nanopolish:
    input:
        batch = lambda wildcards : get_signal_batch(wildcards, config),
        run = lambda wildcards : [os.path.join(config['storage_data_raw'], wildcards.runname)] + [os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn')] if get_signal_batch(wildcards, config).endswith('.txt') else [],
        sequences = lambda wildcards : get_sequence_batch(wildcards, config),
        bam = lambda wildcards : get_alignment_batch(wildcards, config),
        bai = lambda wildcards : get_alignment_batch(wildcards, config) + '.bai',
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    output:
        "methylation/nanopolish/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.tsv"
    shadow: "minimal"
    threads: config['threads_methylation']
    resources:
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, input, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    params:
        index = lambda wildcards : '--index ' + os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn') if get_signal_batch(wildcards, config).endswith('.txt') else ''
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkdir -p raw
        {config[bin][python]} {config[sbin][storage_fast5Index.py]} extract {input.batch} raw/ {params.index} --output_format lazy
        zcat {input.sequences} > sequences.fastx
        {config[bin_singularity][nanopolish]} index -d raw/ sequences.fastx
        {config[bin_singularity][nanopolish]} call-methylation -t {threads} -r sequences.fastx -g {input.reference} -b {input.bam} > {output}
        """

# merge batch tsv files and split connected CpGs
rule methylation_nanopolish_merge_run:
    input:
        lambda wildcards: get_batches_methylation(wildcards, config, 'nanopolish')
    output:
        temp("methylation/nanopolish/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.tsv")
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

# Flappie basecaller methylation alignment
rule methylation_flappie:
    input:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        seq = lambda wildcards, config=config : get_sequence_batch(wildcards, config),
        bam = lambda wildcards, config=config : get_alignment_batch(wildcards, config),
        tsv = lambda wildcards ,config=config : re.sub('.gz$', '.tsv.gz', get_sequence_batch(wildcards, config))
    output:
        "methylation/flappie/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.tsv"
    shadow: "minimal"
    threads: 1
    resources:
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, input, threads, attempt: int((15 / threads) * attempt)   # 15 min / 1 thread
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][samtools]} view -F 4 {input.bam} | {config[bin_singularity][python]} {config[sbin_singularity][methylation_flappie.py]} align {input.reference} {input.seq} {input.tsv} > {output}
        """

# merge batch tsv files
rule methylation_flappie_merge_run:
    input:
        lambda wildcards: get_batches_methylation(wildcards, config, 'flappie')
    output:
        temp("methylation/flappie/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.tsv")
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input} > {output}
        """

# compress methylation caller tsv output
rule methylation_compress:
    input:
        "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.tsv"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.tsv.gz"
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        "cat {input} | sort -k1,1 -k4,4 -k2,2n | gzip > {output}"

# single read methylation tracks for IGV/GViz
rule methylation_single_read_run:
    input:
        tsv = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.tsv.gz",
        bam = "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.bam"
    output:
        bam = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.bam",
        bai = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.bam.bai"
    params:
        reference = lambda wildcards: os.path.abspath(config['references'][wildcards.reference]['genome']),
        threshold = lambda wildcards : config['methylation_nanopolish_logp_threshold'] if wildcards.methylation_caller == 'nanopolish' else config['methylation_flappie_qval_threshold'] if wildcards.methylation_caller == 'flappie' else 0
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin][samtools]} view -hF 4 {input.bam} | {config[bin_singularity][python]} {config[bin][methylation_sr]} {params.reference} {input.tsv} --threshold {params.threshold} --method {wildcards.methylation_caller} --mode IGV --polish | {config[bin][samtools]} view -b > {output.bam}
        {config[bin][samtools]} index {output.bam}
        """

# nanopolish methylation probability to frequencies
rule methylation_nanopolish_frequencies:
    input:
        lambda wildcards : get_batches_methylation2(wildcards, config, 'nanopolish')
    output:
        "methylation/nanopolish/{aligner, [^.\/]*}/{sequence_workflow}/{tag, [^\/]*}.{reference, [^.\/]*}.frequencies.tsv"
    params:
        log_p_threshold = config['methylation_nanopolish_logp_threshold']
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        zcat {input} | cut -f1-3,5 | perl -anle 'if(abs($F[3]) > {params.log_p_threshold}){{if($F[3]>{params.log_p_threshold}){{print join("\t", @F[0..2], "1")}}else{{print join("\t", @F[0..2], "0")}}}}' | sort -k1,1 -k2,2n | {config[bin_singularity][bedtools]} groupby -g 1,2,3 -c 4 -o mean,count > {output}
        """

# flappie methylation with sequences quality to frequencies
rule methylation_flappie_frequencies:
    input:
        lambda wildcards : get_batches_methylation2(wildcards, config, 'flappie')
    output:
        "methylation/flappie/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.\/]*}.frequencies.tsv"
    params:
        qval_threshold = config['methylation_flappie_qval_threshold']
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        zcat {input} | perl -anle 'print $_ if $F[6] > {params.qval_threshold}' | cut -f1-3,5 | sort -k1,1 -k2,2n | {config[bin_singularity][bedtools]} groupby -g 1,2,3 -c 4 -o mean,count > {output}
        """

# frequencies to bedGraph
rule methylation_bedGraph:
    input:
        "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/{tag}.{reference}.frequencies.tsv"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{coverage, [^.\/]*}.{reference, [^.\/]*}.bedGraph"
    params:
        methylation_min_coverage = lambda wildcards : get_min_coverage(wildcards)
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input} | perl -anle 'print $_ if $F[4] >= {params.methylation_min_coverage}' | cut -f1-4 > {output}
        """

# bedGraph to bigWig
rule methylation_bigwig:
    input:
        bedGraph = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/{tag}.{coverage}.{reference}.bedGraph",
        chr_sizes = lambda wildcards : config["references"][wildcards.reference]["chr_sizes"]
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow}/{tag, [^\/]*}.{coverage, [^.\/]*}.{reference, [^.\/]*}.bw"
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][bedGraphToBigWig]} {input.bedGraph} {input.chr_sizes} {output}
        """

# 1D2 matched methylation table
rule methylation_1D2:
    input:
        values = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.tsv.gz",
        pairs = "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.1D2.tsv"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.1D2.tsv.gz"
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][python]} {config[sbin_singularity][methylation_1D2.py]} {input.pairs} {input.values} | gzip > {output}
        """
