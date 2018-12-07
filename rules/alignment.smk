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
import os, glob
localrules: graphmap_index, ngmlr_index, aligner_merge_run, aligner_merge_runs
#ruleorder: aligner_split_run > aligner_sam2bam

# get batches
def get_batches_aligner(wildcards):
    return expand("alignments/{wildcards.runname}/{{batch}}.{wildcards.aligner}.{wildcards.reference}.bam".format(wildcards=wildcards), batch=get_batches(wildcards))

# minimap alignment
rule minimap2:
    input:
        "sequences/{runname}/{batch}.albacore.fa"
    output:
        pipe("alignments/{runname, [^.]*}/{batch, [0-9]+}.minimap2.{reference}.sam")
    threads: config['threads_alignment']
    group: "minimap2"
    params:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    shell:
        """
        {config[bin][minimap2]} -L -ax map-ont {params.reference} {input} -t {threads} >> {output}
        """

# graphmap alignment
rule graphmap:
    input:
        sequence = "sequences/{runname}/{batch}.albacore.fa",
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        index = lambda wildcards: config['references'][wildcards.reference]['genome'] + ".gmidx"
    output:
        pipe("alignments/{runname, [^.]*}/{batch, [0-9]+}.graphmap.{reference}.sam")
    threads: config['threads_alignment']
    group: "graphmap"
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 80000),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt),   # 90 min / 16 threads
    shell:
        """
        {config[bin][graphmap]} align -r {input.reference} -d {input.sequence} -t {threads} -B 100 >> {output}
        """

# graphmap index
rule graphmap_index:
    output:
        index = "{reference}.gmidx"
    params:
        reference = lambda wildcards: wildcards.reference
    shell:
        """
        {config[bin][graphmap]} align -r {params.reference} --index-only
        """

# NGMLR alignment
rule ngmlr:
    input:
        sequence = "sequences/{runname}/{batch}.albacore.fa",
        index = lambda wildcards : config['references'][wildcards.reference]['genome'] + '.ngm'
    output:
        pipe("alignments/{runname, [^.]*}/{batch, [0-9]+}.ngmlr.{reference, [^./]*}.sam")
    threads: config['threads_alignment']
    group: "ngmlr"
    params:
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 32000),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    shell:
        """
        cat {input} | {config[bin][ngmlr]} -r {params.reference} -x ont -t {threads} --bam-fix >> {output}
        """

# NGMLR index
rule ngmlr_index:
    output:
        index = "{reference}.ngm"
    params:
        reference = lambda wildcards: wildcards.reference
    shell:
        """
        echo '' | {config[bin][ngmlr]} -r {params.reference}
        touch {output.index}
        """

# sam to bam conversion and RG tag
rule aligner_sam2bam:
    input:
        "alignments/{runname}/{batch}.{aligner}.{reference}.sam"
    output:
        bam = "alignments/{runname, [^/.]*}/{batch, [0-9]+}.{aligner, [^/.]*}.{reference, [^./]*}.bam",
        bai = "alignments/{runname, [^/.]*}/{batch, [0-9]+}.{aligner, [^/.]*}.{reference, [^./]*}.bam.bai"
    shadow: "minimal"
    threads: 1
    params:
        ID = get_ID
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 5000)
    shell:
        """
        cat {input} | perl -anle 'BEGIN{{$header=1}}; if($header == 1){{ if($_ =~ /^@/) {{print $_}} else {{$header=0; print "\@RG\tID:{wildcards.runname}/{wildcards.batch}"}}}} else {{print $_}}' | perl -anle 'if($_ =~ /^@/){{print $_}}else{{print join("\t", @F, "RG:Z:{wildcards.runname}/{wildcards.batch}")}}' |  {config[bin][samtools]} view -b - | {config[bin][samtools]} sort -m 4G > {output.bam}
        {config[bin][samtools]} index {output.bam}
        """

# merge batch files
rule aligner_merge_run:
    input:
        get_batches_aligner
    output:
        bam = "alignments/{runname, [^./]*}.{aligner, [^/.]*}.{reference, [^/.]*}.bam",
        bai = "alignments/{runname, [^./]*}.{aligner, [^/.]*}.{reference, [^/.]*}.bam.bai"
    shell:
        """
        {config[bin][samtools]} merge {output.bam} {input} -p
        {config[bin][samtools]} index {output.bam}
        """

# create batches by splitting merged bam files
# rule aligner_split_run:
    # input:
        # bam = ancient("alignments/{runname}.{aligner}.{reference}.bam"),
        # bai = ancient("alignments/{runname}.{aligner}.{reference}.bam.bai")
    # output:
        # batch_bam = "alignments/{runname, [^/.]*}/{batch, [0-9]+}.{aligner, [^/.]*}.{reference, [^./]*}.bam",
        # batch_bai = "alignments/{runname, [^/.]*}/{batch, [0-9]+}.{aligner, [^/.]*}.{reference, [^./]*}.bam.bai"
    # shell:
        # """
        # {config[bin][samtools]} view -b -r '{wildcards.runname}/{wildcards.batch}' {input.bam} > {output.batch_bam}
        # {config[bin][samtools]} index {output.batch_bam}
        # """

# merge run files
rule aligner_merge_runs:
    input:
        ['alignments/{runname}.{{aligner}}.{{reference}}.bam'.format(runname=runname) for runname in config['runnames']]
    output:
        bam = "{trackname, [^./]*}.{aligner, [^./]*}.{reference, [^./]*}.bam",
        bai = "{trackname, [^./]*}.{aligner, [^./]*}.{reference, [^./]*}.bam.bai"
    shell:
        """
        {config[bin][samtools]} merge {output.bam} {input} -p
        {config[bin][samtools]} index {output.bam}
        """
