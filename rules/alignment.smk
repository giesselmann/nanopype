# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : nanopore alignment rules
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
localrules: aligner_merge_run, aligner_merge_runs


# get batches
def get_batches_aligner(wildcards):
    return expand("runs/{wildcards.runname}/alignments/{{batch}}.{wildcards.aligner}.{wildcards.reference}.bam".format(wildcards=wildcards), batch=get_batches(wildcards))    


# minimap alignment
rule minimap2:
    input:
        "runs/{runname}/sequences/{batch}.albacore.fa"
    output:
        bam = "runs/{runname}/alignments/{batch}.minimap2.{reference}.bam",
        bai = "runs/{runname}/alignments/{batch}.minimap2.{reference}.bam.bai"
    shadow: "minimal"
    threads: 16
    params:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 32000),
        time_min = lambda wildcards, attempt: int(240 * attempt)
    shell:
        """
        {config[bin][minimap2]} -ax map-ont {params.reference} {input} -t {threads} | {config[bin][samtools]} view -Sb - | {config[bin][samtools]} sort -m 4G > {output.bam}
        {config[bin][samtools]} index {output.bam}
        """

# graphmap alignment
rule graphmap:
    input:
        "runs/{runname}/sequences/{batch}.albacore.fa"
    output:
        bam = "runs/{runname}/alignments/{batch}.graphmap.{reference}.bam",
        bai = "runs/{runname}/alignments/{batch}.graphmap.{reference}.bam.bai"
    shadow: "minimal"
    threads: 16
    params:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 80000),
        time_min = lambda wildcards, attempt: int(240 * attempt)
    shell:
        """
        {config[bin][graphmap]} align -r {params.reference} -d {input} -t {threads} -B 100 | {config[bin][samtools]} view -Sb - | {config[bin][samtools]} sort -m 4G > {output.bam}
        {config[bin][samtools]} index {output.bam}
        """
 
# NGMLR alignment 
rule ngmlr:
    input:
        "runs/{runname}/sequences/{batch}.albacore.fa"
    output:
        bam = "runs/{runname}/alignments/{batch}.ngmlr.{reference}.bam",
        bai = "runs/{runname}/alignments/{batch}.ngmlr.{reference}.bam.bai"
    shadow: "minimal"
    threads: 16
    params:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 32000),
        time_min = lambda wildcards, attempt: int(60 * attempt)
    shell:
        """
        cat {input} | {config[bin][ngmlr]} -r {params.reference} -x ont -t {threads} --bam-fix | {config[bin][samtools]} view -Sb - | {config[bin][samtools]} sort -m 4G > {output.bam}
        {config[bin][samtools]} index {output.bam}
        """

# merge batch files
rule aligner_merge_run:
    input:
        get_batches_aligner
    output:
        "runs/{runname, [a-zA-Z0-9_-]+}.{aligner}.{reference}.bam"
    shell:
        """
        {config[bin][samtools]} merge {output} {input} -p
        {config[bin][samtools]} index {output}
        """
      
# merge run files      
rule aligner_merge_runs:
    input:
        ['runs/{runname}.{{aligner}}.{{reference}}.bam'.format(runname=runname) for runname in config['runnames']]
    output:
        "{trackname, [a-zA-Z0-9_-]+}.{aligner}.{reference}.bam"
    params:
        min_coverage = 1
    shell:
        """
        {config[bin][samtools]} merge {output} {input} -p
        {config[bin][samtools]} index {output}
        """
