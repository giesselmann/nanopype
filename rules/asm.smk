# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : nanopore assembly rules
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
import os, sys
from snakemake.io import glob_wildcards
from rules.utils.get_file import  get_sequence_runs




rule flye:
    input:
        seq = lambda wildcards : get_sequence_runs(wildcards, config)
    output:
        fa = "assembly/flye/{sequence_workflow}/{tag}.fasta"
    threads : config.get('threads_asm') or 1
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['flye'][0] + config['memory']['flye'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((576000 / threads) * attempt * config['runtime']['flye'])   # 120 h / 80 threads
    params:
        out_prefix = lambda wildcards : "assembly/flye/{sequence_workflow}/{tag}".format(sequence_workflow=wildcards.sequence_workflow, tag=wildcards.tag),
        flye_flags = config.get('asm_flye_flags') or '',
        flye_preset = config.get('asm_flye_preset') or '--nano-raw',
        genome_size = lambda wildcards : config.get('asm_genome_size') or '3.0g'
    singularity:
        config['singularity_images']['assembly']
    shell:
        """
        flye_dir=`dirname {config[bin_singularity][python]}`
        PATH=$flye_dir:$PATH
        {config[bin_singularity][python]} {config[bin_singularity][flye]} {params.flye_flags} -g {params.genome_size} -t {threads} {params.flye_preset} {input.seq} -o {params.out_prefix}
        mv {params.out_prefix}/assembly.fasta {output.fa}
        """

rule wtdbg2:
    input:
        seq = lambda wildcards : get_sequence_runs(wildcards, config)
    output:
        fa = "assembly/wtdbg2/{sequence_workflow}/{tag}.fasta"
    threads : config.get('threads_asm') or 1
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['wtdbg2'][0] + config['memory']['wtdbg2'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((576000 / threads) * attempt * config['runtime']['wtdbg2'])   # 120 h / 80 threads
    params:
        out_prefix = lambda wildcards : "assembly/wtdbg2/{sequence_workflow}/{tag}".format(sequence_workflow=wildcards.sequence_workflow, tag=wildcards.tag),
        wtdbg2_flags = config.get('asm_wtdbg2_flags') or '',
        wtdbg2_preset = config.get('asm_wtdbg2_preset') or 'ont',
        genome_size = lambda wildcards : config.get('asm_genome_size') or '3.0g'
    singularity:
        config['singularity_images']['assembly']
    shell:
        """
        mkdir -p {params.out_prefix}
        {config[bin_singularity][wtdbg2]} {params.wtdbg2_flags} -x {params.wtdbg2_preset} -g {params.genome_size} -t {threads} -fo {params.out_prefix}/dbg -i {input.seq}
        {config[bin_singularity][wtpoa-cns]} -t {threads} -i {params.out_prefix}/dbg.ctg.lay.gz -fo {params.out_prefix}/dbg.raw.fa
        {config[bin_singularity][minimap2]} -t {threads} -ax map-ont -r2k {params.out_prefix}/dbg.raw.fa {input.seq} | {config[bin_singularity][samtools]} sort -@ 4 > {params.out_prefix}/dbg.bam
        samtools view -F0x900 {params.out_prefix}/dbg.bam | {config[bin_singularity][wtpoa-cns]} -t {threads} -d {params.out_prefix}/dbg.raw.fa -i - -fo {params.out_prefix}/dbg.cns.fa
        mv {params.out_prefix}/dbg.cns.fa {output.fa}
        """
