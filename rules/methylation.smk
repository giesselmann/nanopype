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
# Copyright (c) 2018-2020, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
localrules: methylation_merge_run, methylation_frequencies
localrules: methylation_run_fofn, methylation_tag_fofn
localrules: methylation_bedGraph, methylation_bigwig
localrules: methylation_single_read_run, methylation_single_read_tag

# get batches
def get_batches_methylation(wildcards, config, methylation_caller=None, runname=None):
    runname=runname or wildcards.runname
    r = expand("methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{reference}",
            methylation_caller=methylation_caller or wildcards.methylation_caller,
            aligner=wildcards.aligner,
            sequence_workflow=wildcards.sequence_workflow,
            tag=wildcards.tag,
            runname=runname,
            reference=wildcards.reference,
            batch=get_batch_ids_raw(runname, config=config, tag=wildcards.tag, checkpoints=checkpoints))
    return r

def get_batches_methylation2(wildcards, config, methylation_caller=None):
    r = expand("methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}",
                        methylation_caller=methylation_caller or wildcards.methylation_caller,
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
        run = lambda wildcards : [os.path.join(config['storage_data_raw'], wildcards.runname)] + ([os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn')] if get_signal_batch(wildcards, config).endswith('.txt') else []),
        sequences = lambda wildcards : get_sequence_batch(wildcards, config),
        bam = lambda wildcards : get_alignment_batch(wildcards, config),
        bai = lambda wildcards : get_alignment_batch(wildcards, config) + '.bai',
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    output:
        "methylation/nanopolish/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.tsv.gz"
    shadow: "shallow"
    threads: config['threads_methylation']
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['nanopolish'][0] + config['memory']['nanopolish'][1] * threads)),
        time_min = lambda wildcards, input, threads, attempt: int((960 / threads) * attempt * config['runtime']['nanopolish'])   # 60 min / 16 threads
    params:
        index = lambda wildcards : '--index ' + os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn') if get_signal_batch(wildcards, config).endswith('.txt') else ''
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkdir -p raw
        {config[bin_singularity][python]} {config[sbin_singularity][storage_fast5Index.py]} extract {input.batch} raw/ {params.index} --output_format lazy
        zcat {input.sequences} > sequences.fastx
        {config[bin_singularity][nanopolish]} index -d raw/ sequences.fastx
        {config[bin_singularity][nanopolish]} call-methylation -t {threads} -r sequences.fastx -g {input.reference} -b {input.bam} | {config[bin_singularity][python]} {config[sbin_singularity][methylation_nanopolish.py]} | sort -k1,1 -k2,2n | gzip > {output}
        """

# Flappie basecaller methylation alignment
rule methylation_flappie:
    input:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        seq = lambda wildcards, config=config : get_sequence_batch(wildcards, config),
        bam = lambda wildcards, config=config : get_alignment_batch(wildcards, config),
        tsv = lambda wildcards ,config=config : re.sub('.fastq.gz$', '.tsv.gz', get_sequence_batch(wildcards, config))
    output:
        "methylation/flappie/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.tsv.gz"
    shadow: "minimal"
    threads: 1
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, input, threads, attempt: int((15 / threads) * attempt)   # 15 min / 1 thread
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][samtools]} view -F 4 {input.bam} | {config[bin_singularity][python]} {config[sbin_singularity][methylation_flappie.py]} align {input.reference} {input.seq} {input.tsv} | sort -k1,1 -k2,2n | gzip > {output}
        """

# Flappie basecaller methylation alignment
rule methylation_guppy:
    input:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        bam = lambda wildcards, config=config : get_alignment_batch(wildcards, config),
        hdf5 = lambda wildcards ,config=config : re.sub('.fastq.gz$', '.hdf5', get_sequence_batch(wildcards, config))
    output:
        "methylation/guppy/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.tsv.gz"
    shadow: "minimal"
    threads: 1
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (5000 + 500 * threads)),
        time_min = lambda wildcards, input, threads, attempt: int((15 / threads) * attempt)   # 15 min / 1 thread
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][samtools]} view -F 4 {input.bam} | {config[bin_singularity][python]} {config[sbin_singularity][basecalling_guppy_mod.py]} align {input.hdf5} --reference {input.reference} | sort -k1,1 -k2,2n | gzip > {output}
        """

# merge batch tsv files
rule methylation_merge_run:
    input:
        lambda wildcards: [f + ".tsv.gz" for f in get_batches_methylation(wildcards, config)]
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, ^.\/#]*}.tsv.gz"
    run:
        with open(output[0], 'wb') as fp_out:
            for f in sorted(input):     # sort by file name, you never know
                with open(f, 'rb') as fp_in:
                    fp_out.write(fp_in.read())

rule methylation_run_fofn:
    input:
        lambda wildcards: [f + ".tsv.gz" for f in get_batches_methylation(wildcards, config)]
    output:
        temp("methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.fofn")
    run:
        with open(output[0], 'w') as fp_out:
            print('\n'.join([re.sub('.tsv.gz$','',f) for f in sorted(input)]), file=fp_out)

rule methylation_tag_fofn:
    input:
        lambda wildcards: [f + ".fofn" for f in get_batches_methylation2(wildcards, config)]
    output:
        temp("methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.\/#]*}.fofn")
    run:
        with open(output[0], 'w') as fp_out:
            print(''.join(open(f, 'r').read() for f in sorted(input)), file=fp_out, end='')

# methylation probability to frequencies
rule methylation_frequencies:
    input:
        "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/{tag}.{reference}.fofn"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.\/]*}.frequencies.tsv.gz"
    resources:
        threads = lambda wildcards, threads: threads,
    params:
        threshold = lambda wildcards : config['methylation_nanopolish_logp_threshold'] if wildcards.methylation_caller == 'nanopolish' else config['methylation_flappie_qval_threshold'] if wildcards.methylation_caller == 'flappie' else config['methylation_guppy_prob_threshold'] if wildcards.methylation_caller == 'guppy' else 0
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input} | while read line; do zcat ${{line}}.tsv.gz; done | perl -anle 'print $_ if abs($F[6]) > {params.threshold}' | cut -f1-3,5 | sort -k1,1 -k2,2n | {config[bin_singularity][bedtools]} groupby -g 1,2,3 -c 4 -o mean,count | gzip > {output}
        """

# frequencies to bedGraph
rule methylation_bedGraph:
    input:
        "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/{tag}.{reference}.frequencies.tsv.gz"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{coverage, [^.\/]*}.{reference, [^.\/]*}.bedGraph"
    resources:
        threads = lambda wildcards, threads: threads,
    params:
        methylation_min_coverage = lambda wildcards : get_min_coverage(wildcards)
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        zcat {input} | perl -anle 'print $_ if $F[4] >= {params.methylation_min_coverage}' | cut -f1-4 > {output}
        """

# bedGraph to bigWig
rule methylation_bigwig:
    input:
        bedGraph = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/{tag}.{coverage}.{reference}.bedGraph",
        chr_sizes = lambda wildcards : config["references"][wildcards.reference]["chr_sizes"]
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{coverage, [^.\/]*}.{reference, [^.\/]*}.bw"
    resources:
        threads = lambda wildcards, threads: threads,
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][bedGraphToBigWig]} {input.bedGraph} {input.chr_sizes} {output}
        """

# single read methylation tracks for IGV/GViz
rule methylation_single_read:
    input:
        tsv = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{reference}.tsv.gz",
        bam = lambda wildcards : get_alignment_batch(wildcards, config),
    output:
        bam = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.bam",
        bai = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.bam.bai"
    threads: 1
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = 16000,
        time_min = 15
    params:
        reference = lambda wildcards: os.path.abspath(config['references'][wildcards.reference]['genome']),
        threshold = lambda wildcards : config['methylation_nanopolish_logp_threshold'] if wildcards.methylation_caller == 'nanopolish' else config['methylation_flappie_qval_threshold'] if wildcards.methylation_caller == 'flappie' else config['methylation_guppy_prob_threshold'] if wildcards.methylation_caller == 'guppy' else 0
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][samtools]} view -hF 4 {input.bam} | {config[bin_singularity][python]} {config[sbin_singularity][methylation_sr.py]} {params.reference} {input.tsv} --threshold {params.threshold} --mode IGV --polish | {config[bin_singularity][samtools]} view -b > {output.bam}
        {config[bin_singularity][samtools]} index {output.bam}
        """

rule methylation_single_read_run:
    input:
        fofn = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.fofn",
        bam = lambda wildcards: [f + ".bam" for f in get_batches_methylation(wildcards, config)]
    output:
        bam = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.bam"
    threads: config.get('threads_samtools') or 1
    resources:
        threads = lambda wildcards, threads: threads,
    params:
        input_prefix = lambda wildcards, input : input.fofn[:-5]
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input.fofn} | while read line; do echo ${{line}}.bam; done | split -l $((`ulimit -n` -10)) - {params.input_prefix}.part_
        for f in {params.input_prefix}.part_*; do {config[bin_singularity][samtools]} merge ${{f}}.bam -b ${{f}} -p -@ {threads}; done
        for f in {params.input_prefix}.part_*.bam; do {config[bin_singularity][samtools]} index ${{f}} -@ {threads}; done
        {config[bin_singularity][samtools]} merge {output.bam} {params.input_prefix}.part_*.bam -p -@ {threads}
        {config[bin_singularity][samtools]} index {output.bam} -@ {threads}
        rm {params.input_prefix}.part_*
        """

rule methylation_single_read_tag:
    input:
        fofn = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/{tag}.{reference}.fofn",
        bam = lambda wildcards: [f + ".bam" for runname in config['runnames'] for f in get_batches_methylation(wildcards, config, runname=runname)]
    output:
        bam = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.\/]*}.bam"
    threads: config.get('threads_samtools') or 1
    resources:
        threads = lambda wildcards, threads: threads,
    params:
        input_prefix = lambda wildcards, input : input.fofn[:-5]
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input.fofn} | while read line; do echo ${{line}}.bam; done | split -l $((`ulimit -n` -10)) - {params.input_prefix}.part_
        for f in {params.input_prefix}.part_*; do {config[bin_singularity][samtools]} merge ${{f}}.bam -b ${{f}} -p -@ {threads}; done
        for f in {params.input_prefix}.part_*.bam; do {config[bin_singularity][samtools]} index ${{f}} -@ {threads}; done
        {config[bin_singularity][samtools]} merge {output.bam} {params.input_prefix}.part_*.bam -p -@ {threads}
        {config[bin_singularity][samtools]} index {output.bam} -@ {threads}
        rm {params.input_prefix}.part_*
        """

# 1D2 matched methylation table
rule methylation_1D2:
    input:
        values = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.tsv.gz",
        pairs = "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.1D2.tsv"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.\/]*}.1D2.tsv.gz"
    resources:
        threads = lambda wildcards, threads: threads,
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][python]} {config[sbin_singularity][methylation_1D2.py]} {input.pairs} {input.values} | gzip > {output}
        """
