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
from rules.utils.get_file import get_batch_ids_raw, get_sequence_batch, get_alignment_batch
# local rules
localrules: methylation_nanopolish_merge_run, methylation_nanopolish_frequencies
localrules: methylation_flappie_merge_run, methylation_flappie_frequencies
localrules: methylation_bedGraph, methylation_bigwig, methylation_compress

# get batches
def get_batches_methylation(wildcards, methylation_caller):
    return expand("methylation/{methylation_caller}/{wildcards.aligner}/{wildcards.basecaller}/batches/{wildcards.runname}/{{batch}}.{wildcards.reference}.tsv".format(wildcards=wildcards, methylation_caller=methylation_caller), batch=get_batch_ids_raw(wildcards.runname, config=config))

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
        signals = lambda wildcards : "{data_raw}/{{runname}}/reads/{{batch}}.{ext}".format(data_raw = config["storage_data_raw"], ext=get_batch_ext(wildcards, config)),
        sequences = lambda wildcards ,config=config : get_sequence_batch(wildcards, config),
        bam = lambda wildcards, config=config : get_alignment_batch(wildcards, config),
        bai = lambda wildcards, config=config : get_alignment_batch(wildcards, config) + '.bai',
        reference = lambda wildcards: os.path.abspath(config['references'][wildcards.reference]['genome'])
    output:
        "methylation/nanopolish/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}/{batch, [^.\/]*}.{reference, [^.\/]*}.tsv"
    shadow: "minimal"
    threads: config['threads_methylation']
    resources:
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, input, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    params:
        batch_base = lambda wildcards : os.path.join(config['storage_data_raw'], 'reads', wildcards.runname)
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkdir -p raw
        {config[sbin_singularity][storage_batch2fast5.sh]} {input.signals} {params.batch_base} raw/ {config[sbin_singularity][base]} {config[bin_singularity][python]}
        zcat {input.sequences} > sequences.fasta
        {config[bin_singularity][nanopolish]} index -d raw/ sequences.fasta
        {config[bin_singularity][nanopolish]} call-methylation -t {threads} -r sequences.fasta -g {input.reference} -b {input.bam} > {output}
        """

# merge batch tsv files and split connected CpGs
rule methylation_nanopolish_merge_run:
    input:
        lambda wildcards: get_batches_methylation(wildcards, 'nanopolish')
    output:
        temp("methylation/nanopolish/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}.{reference, [^.\/]*}.tsv")
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
        reference = lambda wildcards: os.path.abspath(config['references'][wildcards.reference]['genome']),
        seq = lambda wildcards, config=config : get_sequence_batch(wildcards, config),
        bam = lambda wildcards, config=config : get_alignment_batch(wildcards, config),
        tsv = lambda wildcards ,config=config : re.sub('.gz$', '.tsv.gz', get_sequence_batch(wildcards, config))
    output:
        "methylation/flappie/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}/{batch, [^.\/]*}.{reference, [^.\/]*}.tsv"
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
        lambda wildcards: get_batches_methylation(wildcards, 'flappie')
    output:
        temp("methylation/flappie/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}.{reference, [^.\/]*}.tsv")
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input} > {output}
        """

# compress methylation caller tsv output
rule methylation_compress:
    input:
        "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{runname}.{reference}.tsv"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}.{reference, [^.\/]*}.tsv.gz"
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        "cat {input} | sort -k1,1 -k4,4 -k2,2n | gzip > {output}"
        
# single read methylation tracks for IGV/GViz
rule methylation_single_read_run:
    input:
        tsv = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{runname}.{reference}.tsv.gz",
        bam = "alignments/{aligner}/{sequence_workflow}/batches/{runname}.{reference}.bam"
    output:
        bam = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}.{reference, [^.\/]*}.bam",
        bai = "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}.{reference, [^.\/]*}.bam.bai"
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
        ['methylation/nanopolish/{{aligner}}/{{sequence_workflow}}/batches/{runname}.{{reference}}.tsv.gz'.format(runname=runname) for runname in config['runnames']]
    output:
        "methylation/nanopolish/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^.\/]*}.{reference, [^.\/]*}.frequencies.tsv"
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
        ['methylation/flappie/{{aligner}}/{{sequence_workflow}}/batches/{runname}.{{reference}}.tsv.gz'.format(runname=runname) for runname in config['runnames']]
    output:
        "methylation/flappie/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^.\/]*}.{reference, [^.\/]*}.frequencies.tsv"
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
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^.\/]*}.{coverage, [^.\/]*}.{reference, [^.\/]*}.bedGraph"
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
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow}/{tag, [^.\/]*}.{coverage, [^.\/]*}.{reference, [^.\/]*}.bw"
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][bedGraphToBigWig]} {input.bedGraph} {input.chr_sizes} {output}
        """

# 1D2 matched methylation table
rule methylation_1D2:
    input:
        values = "methylation/{methylation_caller}/{aligner}/{sequence_workflow}/batches/{runname}.{reference}.tsv.gz",
        pairs = "alignments/{aligner}/{sequence_workflow}/batches/{runname}.{reference}.1D2.tsv"
    output:
        "methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{runname, [^.\/]*}.{reference, [^.\/]*}.1D2.tsv.gz"
    singularity:
        "docker://nanopype/methylation:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][python]} {config[sbin_singularity][methylation_1D2.py]} {input.pairs} {input.values} | gzip > {output}
        """
