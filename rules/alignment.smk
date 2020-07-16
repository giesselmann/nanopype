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
import os, glob
from rules.utils.get_file import get_batch_ids_raw, get_sequence_batch
from rules.utils.storage import get_ID
# local rules
localrules: graphmap_index, ngmlr_index, aligner_merge_batches, aligner_merge_tag, aligner_1D2
localrules: aligner_merge_batches_names, aligner_merge_tag_names
#ruleorder: aligner_sam2bam > aligner_merge_batches_run

# get batches
def get_batches_aligner(wildcards, config):
    r = expand("alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{reference}.bam",
                        aligner=wildcards.aligner,
                        sequence_workflow=wildcards.sequence_workflow,
                        tag=wildcards.tag,
                        runname=wildcards.runname,
                        batch=get_batch_ids_raw(wildcards.runname, config=config, tag=wildcards.tag, checkpoints=checkpoints),
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
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * (config['memory']['minimap2'][0] + config['memory']['minimap2'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt * config['runtime']['minimap2'])   # 60 min / 16 threads
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][minimap2]} -t {threads} {config[alignment_minimap2_flags]} {input.reference} {input.sequence} >> {output}
        """

# graphmap2 alignment
rule graphmap2:
    input:
        sequence = lambda wildcards: get_sequence_batch(wildcards, config),
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        index = lambda wildcards: config['references'][wildcards.reference]['genome'] + ".gmidx"
    output:
        pipe("alignments/graphmap2/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference}.sam")
    threads: config['threads_alignment']
    group: "graphmap2"
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * (config['memory']['graphmap2'][0] + config['memory']['graphmap2'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt * config['runtime']['graphmap2']),   # 90 min / 16 threads
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][graphmap2]} align -r {input.reference} -d {input.sequence} -t {threads} {config[alignment_graphmap2_flags]} >> {output}
        """

# graphmap index
rule graphmap_index:
    input:
        fasta = "{reference}.{ext}"
    output:
        index = "{reference}.{ext, (fa|fasta)}.gmidx"
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][graphmap2]} align -r {input.fasta} --index-only
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
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * (config['memory']['ngmlr'][0] + config['memory']['ngmlr'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((5760 / threads) * attempt * config['runtime']['ngmlr'])   # 360 min / 16 threads
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        cat {input.sequence} | {config[bin_singularity][ngmlr]} -r {input.reference} -t {threads} {config[alignment_ngmlr_flags]} >> {output}
        """

# NGMLR index
rule ngmlr_index:
    input:
        fasta = "{reference}.{ext}"
    output:
        index = "{reference}.{ext, (fa|fasta)}.ngm"
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

rule aligner_merge_batches_names:
    input:
        bam = lambda wildcards: get_batches_aligner(wildcards, config)
    output:
        txt = temp("alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.txt")
    run:
        with open(output.txt, 'w') as fp:
            print('\n'.join(input.bam), file=fp)

# merge batch files
rule aligner_merge_batches:
    input:
        bam = "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.txt"
    output:
        bam = "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.bam",
        bai = "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.bam.bai"
    threads: config.get('threads_samtools') or 1
    params:
        input_prefix = lambda wildcards, input : input.bam[:-4]
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        split -l $((`ulimit -n` -10)) {input.bam} {params.input_prefix}.part_
        for f in {params.input_prefix}.part_*; do {config[bin_singularity][samtools]} merge ${{f}}.bam -b ${{f}} -p -@ {threads}; done
        for f in {params.input_prefix}.part_*.bam; do {config[bin_singularity][samtools]} index ${{f}} -@ {threads}; done
        {config[bin_singularity][samtools]} merge {output.bam} {params.input_prefix}.part_*.bam -p -@ {threads}
        {config[bin_singularity][samtools]} index {output.bam} -@ {threads}
        rm {params.input_prefix}.part_*
        """

rule aligner_merge_tag_names:
    input:
        txt = lambda wildcards: expand("alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.txt",
                aligner=wildcards.aligner,
                sequence_workflow=wildcards.sequence_workflow,
                tag=wildcards.tag,
                runname=[runname for runname in config['runnames']],
                reference=wildcards.reference)
    output:
        txt = temp("alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.txt")
    run:
        with open(output.txt, 'w') as fp_out:
            for f in input.txt:
                with open(f, 'r') as fp_in:
                    fp_out.write(fp_in.read())

rule aligner_merge_tag:
    input:
        bam = "alignments/{aligner}/{sequence_workflow}/{tag}.{reference}.txt"
    output:
        bam = "alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bam",
        bai = "alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bam.bai"
    threads: config.get('threads_samtools') or 1
    params:
        input_prefix = lambda wildcards, input : input.bam[:-4]
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        split -l $((`ulimit -n` -10)) {input.bam} {params.input_prefix}.part_
        for f in {params.input_prefix}.part_*; do {config[bin_singularity][samtools]} merge ${{f}}.bam -b ${{f}} -p -@ {threads}; done
        for f in {params.input_prefix}.part_*.bam; do {config[bin_singularity][samtools]} index ${{f}} -@ {threads}; done
        {config[bin_singularity][samtools]} merge {output.bam} {params.input_prefix}.part_*.bam -p -@ {threads}
        {config[bin_singularity][samtools]} index {output.bam} -@ {threads}
        rm {params.input_prefix}.part_*
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

# mapping stats
rule aligner_stats:
    input:
        "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}.{reference}.txt"
    output:
        "alignments/{aligner, [^.\/]*}/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.hdf5"
    threads: config.get('threads_samtools') or 1
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        while IFS= read -r bam_file; do {config[bin_singularity][samtools]} view ${{bam_file}}; done < {input} | {config[bin_singularity][python]} {config[sbin_singularity][alignment_stats.py]} {output}
        """

# coverage
rule aligner_coverage:
    input:
        bam = "alignments/{aligner}/{sequence_workflow}/{tag}.{reference}.txt",
        chr_sizes = lambda wildcards : config["references"][wildcards.reference]["chr_sizes"]
    output:
        bedGraph = "alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bedGraph",
        bw = "alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bw"
    threads: config.get('threads_samtools') or 1
    singularity:
        "docker://nanopype/alignment:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        while IFS= read -r bam_file; do {config[bin_singularity][samtools]} view -bF 4 ${{bam_file}} -@ {threads} | {config[bin_singularity][bedtools]} bamtobed -i stdin; done < {input.bam} | {config[bin_singularity][python]} {config[sbin_singularity][alignment_cov.py]} {input.chr_sizes} > {output.bedGraph}
        {config[bin_singularity][bedGraphToBigWig]} {output.bedGraph} {input.chr_sizes} {output.bw}
        """
