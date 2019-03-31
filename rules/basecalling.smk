# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : nanopore basecalling rules
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
import os, sys
from rules.utils.get_file import get_batch_ids_raw, get_batch_ext
from rules.utils.storage import get_flowcell, get_kit
# local rules
localrules: basecaller_merge_batches, basecaller_merge_tag, basecaller_qc

# get batches
def get_batches_basecaller(wildcards, config):
    r = expand("sequences/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{format}.gz",
                        sequence_workflow=wildcards.sequence_workflow,
                        tag=wildcards.tag,
                        runname=wildcards.runname,
                        batch=get_batch_ids_raw(wildcards.runname, config),
                        format=wildcards.format)
    return r

def get_batches_runname(wildcards, config):
    r = expand("sequences/{sequence_workflow}/batches/{tag}/{runname}.{format}.gz",
                        sequence_workflow=wildcards.sequence_workflow,
                        tag=wildcards.tag,
                        runname=[runname for runname in config['runnames']],
                        format=wildcards.format)
    return r

# albacore basecalling
rule albacore:
    input:
        lambda wildcards : "{data_raw}/{{runname}}/reads/{{batch}}.{ext}".format(
            data_raw = config["storage_data_raw"],
            ext=get_batch_ext(wildcards, config))
    output:
        "sequences/albacore/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shadow: "minimal"
    threads: config['threads_basecalling']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (4000 + 1000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt) # 60 min / 16 threads
    params:
        flowcell = lambda wildcards: get_flowcell(wildcards, config),
        kit = lambda wildcards: get_kit(wildcards, config),
        barcoding = lambda wildcards : '--barcoding' if config['basecalling_albacore_barcoding'] else '',
        filtering = lambda wildcards : '--disable_filtering' if config['basecalling_albacore_disable_filtering'] else ''
    shell:
        """
        mkdir -p raw
        {config[sbin][storage_batch2fast5.sh]} {input} raw/ {config[sbin][base]} {config[bin][python]}
        {config[bin][albacore]} -i raw/ --recursive -t {threads} -s raw/ --flowcell {params.flowcell} --kit {params.kit} --output_format fastq {params.filtering} {params.barcoding} {config[basecalling_albacore_flags]}
        FASTQ_DIR='raw/workspace/'
        if [ \'{params.filtering}\' = '' ]; then
            FASTQ_DIR='raw/workspace/pass'
        fi
        find ${{FASTQ_DIR}} -regextype posix-extended -regex '^.*f(ast)?q' -exec cat {{}} \; > {wildcards.batch}.fq
        if [[ \'{wildcards.format}\' == *'q'* ]]; then
            cat {wildcards.batch}.fq | gzip > {output}
        else
            cat {wildcards.batch}.fq | tr '\t' ' ' | paste - - - - | cut -d '\t' -f1,2 | tr '@' '>' | tr '\t' '\n' | gzip > {output}
        fi
        """

# guppy basecalling
rule guppy:
    input:
        lambda wildcards : "{data_raw}/{{runname}}/reads/{{batch}}.{ext}".format(
            data_raw = config["storage_data_raw"],
            ext=get_batch_ext(wildcards, config))
    output:
        "sequences/guppy/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shadow: "minimal"
    threads: config['threads_basecalling']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 4000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt) # 90 min / 16 threads
    params:
        flowcell = lambda wildcards: get_flowcell(wildcards, config),
        kit = lambda wildcards: get_kit(wildcards, config),
        #barcoding = lambda wildcards : '--barcoding' if config['basecalling_albacore_barcoding'] else '',
        filtering = lambda wildcards : '--qscore_filtering --min_qscore {score}'.format(score = config['basecalling_guppy_qscore_filter']) if config['basecalling_guppy_qscore_filter'] > 0 else ''
    singularity:
        "docker://nanopype/basecalling:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkdir -p raw
        {config[sbin_singularity][storage_batch2fast5.sh]} {input} raw/ {config[sbin_singularity][base]} {config[bin_singularity][python]}
        {config[bin_singularity][guppy]} -i raw/ --recursive --num_callers 1 --cpu_threads_per_caller {threads} -s workspace/ --flowcell {params.flowcell} --kit {params.kit} {params.filtering} {config[basecalling_guppy_flags]}
        FASTQ_DIR='workspace/pass'
        if [ \'{params.filtering}\' = '' ]; then
            FASTQ_DIR='workspace'
        fi
        find ${{FASTQ_DIR}} -regextype posix-extended -regex '^.*f(ast)?q' -exec cat {{}} \; > {wildcards.batch}.fq
        if [[ \'{wildcards.format}\' == *'q'* ]]; then
            cat {wildcards.batch}.fq | gzip > {output}
        else
            cat {wildcards.batch}.fq | tr '\t' ' ' | paste - - - - | cut -d '\t' -f1,2 | tr '@' '>' | tr '\t' '\n' | gzip > {output}
        fi
        """

# flappie basecalling
rule flappie:
    input:
        lambda wildcards : "{data_raw}/{{runname}}/reads/{{batch}}.{ext}".format(
            data_raw = config["storage_data_raw"],
            ext=get_batch_ext(wildcards, config))
    output:
        sequence = "sequences/flappie/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.gz",
        methyl_marks = "sequences/flappie/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.tsv.gz"
    shadow: "minimal"
    threads: config['threads_basecalling']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (4000 + 5000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((5760 / threads) * attempt) # 360 min / 16 threads
    singularity:
        "docker://nanopype/basecalling:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        export OPENBLAS_NUM_THREADS=1
        mkdir -p raw
        {config[sbin_singularity][storage_batch2fast5.sh]} {input} raw/ {config[sbin_singularity][base]} {config[bin_singularity][python]}
        find raw/ -regextype posix-extended -regex '^.*fast5' -type f -exec du -h {{}} + | sort -r -h | cut -f2 > raw.fofn
        split -e -n r/{threads} raw.fofn raw.fofn.part.
        ls raw.fofn.part.* | xargs -n 1 -P {threads} -I {{}} $SHELL -c 'cat {{}} | shuf | xargs -n 1 {config[bin_singularity][flappie]} --model {config[basecalling_flappie_model]} {config[basecalling_flappie_flags]} > raw/{{}}.fastq'
        find ./raw -regextype posix-extended -regex '^.*f(ast)?q' -exec cat {{}} \; > {wildcards.batch}.fq
        if [[ \'{wildcards.format}\' == *'q'* ]]; then
            cat {wildcards.batch}.fq | {config[bin_singularity][python]} {config[sbin_singularity][methylation_flappie.py]} split methyl_marks.tsv | gzip > {output.sequence}
        else
            cat {wildcards.batch}.fq | {config[bin_singularity][python]} {config[sbin_singularity][methylation_flappie.py]} split methyl_marks.tsv | tr '\t' ' ' | paste - - - - | cut -d '\t' -f1,2 | tr '@' '>' | tr '\t' '\n' | gzip > {output.sequence}
        fi
        cat methyl_marks.tsv | gzip > {output.methyl_marks}
        """

# merge and compression
rule basecaller_merge_batches:
    input:
        lambda wildcards: get_batches_basecaller(wildcards, config)
    output:
        "sequences/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shell:
        "cat {input} > {output}"

rule basecaller_merge_tag:
    input:
        lambda wildcards: get_batches_runname(wildcards, config)
    output:
        "sequences/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shell:
        "cat {input} > {output}"

# basecalling QC
rule fastx_stats:
    input:
        "{file}.{format}.gz"
    output:
        temp("{file}.{format, (fasta|fastq|fa|fq)}.qc.tsv")
    resources:
        time_min = lambda wildcards, threads, attempt: int(60 * attempt) # 60 min / 1 thread
    run:
        import rules.utils.basecalling_fastx_stats
        rules.utils.basecalling_fastx_stats.main(input[0], output=output[0])

# report from basecalling
rule basecaller_qc:
    input:
        tsv = "{file}.{format}.qc.tsv"
    output:
        pdf = "{file}.{format, (fasta|fastq|fa|fq)}.pdf"
    singularity:
        "docker://nanopype/analysis:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        wd=$(pwd)
        cp {config[sbin_singularity][basecalling_qc.Rmd]} ./
        Rscript --vanilla -e 'rmarkdown::render("basecalling_qc.Rmd")' ${{wd}}/{input.tsv}
        rm ./basecalling_qc.Rmd
        mv basecalling_qc.pdf {output.pdf}
        """
