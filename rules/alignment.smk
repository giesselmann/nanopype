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
import os, glob
from rules.utils.get_file import get_batch_ids_raw, get_sequence_batch
from rules.utils.storage import get_ID
# local rules
localrules: graphmap_index, ngmlr_index, aligner_merge_batches, aligner_merge_tag, aligner_1D2
#ruleorder: aligner_sam2bam > aligner_merge_batches_run

# get batches
def get_batches_aligner(wildcards, config):
    r = expand("alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{reference}.bam",
                        aligner=wildcards.aligner,
                        sequence_workflow=wildcards.sequence_workflow,
                        tag=wildcards.tag,
                        runname=wildcards.runname,
                        batch=get_batch_ids_raw(wildcards.runname, config),
                        reference=wildcards.reference)
    return r

def get_batches_aligner2(wildcards, config):
    r = expand("alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.bam",
                        aligner=wildcards.aligner,
                        sequence_workflow=wildcards.sequence_workflow,
                        tag=wildcards.tag,
                        runname=[runname for runname in config['runnames']],
                        reference=wildcards.reference)
    return r


# minimap alignment
rule minimap2:
    input:
        sequence = lambda wildcards: get_sequence_batch(wildcards, config),
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    output:
        pipe("alignments/minimap2/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference}.sam")
    threads: config['threads_alignment']
    group: "minimap2"
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][minimap2]} -t {threads} {config[alignment_minimap2_flags]} {input.reference} {input.sequence} >> {output}
        """

# graphmap alignment
rule graphmap:
    input:
        sequence = lambda wildcards: get_sequence_batch(wildcards, config),
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        index = lambda wildcards: config['references'][wildcards.reference]['genome'] + ".gmidx"
    output:
        pipe("alignments/graphmap/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference}.sam")
    threads: config['threads_alignment']
    group: "graphmap"
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 80000),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt),   # 90 min / 16 threads
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][graphmap]} align -r {input.reference} -d {input.sequence} -t {threads} {config[alignment_graphmap_flags]} >> {output}
        """

# graphmap index
rule graphmap_index:
    input:
        fasta = "{reference}.fa"
    output:
        index = "{reference}.fa.gmidx"
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][graphmap]} align -r {input.fasta} --index-only
        """

# NGMLR alignment
rule ngmlr:
    input:
        sequence = lambda wildcards: get_sequence_batch(wildcards, config),
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        index = lambda wildcards : directory(os.path.dirname(config['references'][wildcards.reference]['genome'])),
        index_flag = lambda wildcards: config['references'][wildcards.reference]['genome'] + '.ngm'
    output:
        pipe("alignments/ngmlr/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference}.sam")
    threads: config['threads_alignment']
    group: "ngmlr"
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 32000),
        time_min = lambda wildcards, threads, attempt: int((5760 / threads) * attempt)   # 360 min / 16 threads
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input.sequence} | {config[bin_singularity][ngmlr]} -r {input.reference} -t {threads} {config[alignment_ngmlr_flags]} >> {output}
        """

# NGMLR index
rule ngmlr_index:
    input:
        fasta = "{reference}.fa"
    output:
        index = "{reference}.fa.ngm"
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        echo '' | {config[bin_singularity][ngmlr]} -r {input.fasta}
        touch {output.index}
        """

# sam to bam conversion and RG tag
rule aligner_sam2bam:
    input:
        sam = "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{reference}.sam"
    output:
        bam = "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.]*}.bam",
        bai = "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.]*}.bam.bai"
    shadow: "minimal"
    threads: 1
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.2 * (attempt - 1))) * 5000)
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input.sam} | perl -anle 'BEGIN{{$header=1}}; if($header == 1){{ if($_ =~ /^@/) {{print $_}} else {{$header=0; print "\@RG\tID:{wildcards.batch}"}}}} else {{print $_}}' | perl -anle 'if($_ =~ /^@/){{print $_}}else{{print join("\t", @F, "RG:Z:{wildcards.batch}")}}' |  {config[bin_singularity][samtools]} view -b {config[alignment_samtools_flags]} - | {config[bin_singularity][samtools]} sort -m 4G > {output.bam}
        {config[bin_singularity][samtools]} index {output.bam}
        """

# merge batch files
rule aligner_merge_batches:
    input:
        bam = lambda wildcards: get_batches_aligner(wildcards, config)
    output:
        bam = "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.bam",
        bai = "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.bam.bai"
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][samtools]} merge {output.bam} {input} -p
        {config[bin_singularity][samtools]} index {output.bam}
        """

rule aligner_merge_tag:
    input:
        bam = lambda wildcards: get_batches_aligner2(wildcards, config)
    output:
        bam = "alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bam",
        bai = "alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bam.bai"
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][samtools]} merge {output.bam} {input} -p
        {config[bin_singularity][samtools]} index {output.bam}
        """

# match 1D2 read pairs
rule aligner_1D2:
    input:
        "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.bam"
    output:
        "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.1D2.tsv"
    params:
        buffer = 200,
        tolerance = 200
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][samtools]} view -F 4 {input} | {config[bin_singularity][python]} {config[sbin_singularity][alignment_1D2.py]} --buffer {params.buffer} --tolerance {params.tolerance} > {output}
        """
