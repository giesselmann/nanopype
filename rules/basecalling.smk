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
from rules.utils.get_file import get_batches, get_sequence
from rules.utils.storage import get_flowcell, get_kit
# local rules
localrules: basecaller_merge_run, basecaller_merge_runs
ruleorder: basecaller_compress > guppy > albacore > flappie
# local config
config['bin']['basecalling_qc'] = os.path.abspath(os.path.join(workflow.basedir, 'rules/utils/basecalling_qc.Rmd'))
config['bin']['methylation_flappie'] = os.path.abspath(os.path.join(workflow.basedir, 'rules/utils/methylation_flappie.py'))

# get batches
def get_batches_basecaller(wildcards):
    batches = expand("sequences/{wildcards.basecaller}/runs/{wildcards.runname}/{{batch}}.{wildcards.format}.gz".format(wildcards=wildcards), batch=get_batches(wildcards, config=config))
    return batches


# albacore basecalling
rule albacore:
    input:
        "{data_raw}/{{runname}}/reads/{{batch}}.tar".format(data_raw = config["storage_data_raw"]),
    output:
        "sequences/albacore/runs/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shadow: "minimal"
    threads: config['threads_basecalling']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (4000 + 1000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt) # 60 min / 16 threads
    params:
        flowcell = lambda wildcards, config=config : get_flowcell(wildcards, config),
        kit = lambda wildcards, config=config : get_kit(wildcards, config),
        barcoding = lambda wildcards : '--barcoding' if config['basecalling_albacore_barcoding'] else '',
        filtering = lambda wildcards : '--disable_filtering' if config['basecalling_albacore_disable_filtering'] else ''
    shell:
        """
        mkdir -p raw
        tar -C raw/ -xf {input}
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
        "{data_raw}/{{runname}}/reads/{{batch}}.tar".format(data_raw = config["storage_data_raw"]),
    output:
        "sequences/guppy/runs/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shadow: "minimal"
    threads: config['threads_basecalling']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 4000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt) # 90 min / 16 threads
    params:
        flowcell = lambda wildcards, config=config : get_flowcell(wildcards, config),
        kit = lambda wildcards, config=config : get_kit(wildcards, config),
        #barcoding = lambda wildcards : '--barcoding' if config['basecalling_albacore_barcoding'] else '',
        filtering = lambda wildcards : '--qscore_filtering --min_qscore {score}'.format(score = config['basecalling_guppy_qscore_filter']) if config['basecalling_guppy_qscore_filter'] > 0 else ''
    singularity:
        "docker://nanopype/basecalling"
    shell:
        """
        mkdir -p raw
        tar -C raw/ -xf {input}
        {config[bin_singularity][guppy]} -i raw/ --recursive --cpu_threads_per_caller {threads} -s workspace/ --flowcell {params.flowcell} --kit {params.kit} {params.filtering} {config[basecalling_guppy_flags]}
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
        "{data_raw}/{{runname}}/reads/{{batch}}.tar".format(data_raw = config["storage_data_raw"])
    output:
        sequence = "sequences/flappie/runs/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.gz",
        methyl_marks = "sequences/flappie/runs/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fasta|fastq|fa|fq)}.tsv.gz"
    shadow: "minimal"
    threads: config['threads_basecalling']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (4000 + 5000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((5760 / threads) * attempt) # 360 min / 16 threads
    params:
        py_bin = lambda wildcards : get_python(wildcards)
    singularity:
        "docker://nanopype/basecalling"
    shell:
        """
        export OPENBLAS_NUM_THREADS=1
        mkdir -p raw
        tar -C raw/ -xf {input}
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
rule basecaller_merge_run:
    input:
        get_batches_basecaller
    output:
        "sequences/{basecaller, [^.\/]*}/runs/{runname, [^.\/]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shell:
        "cat {input} > {output}"

# merge run files
rule basecaller_merge_runs:
    input:
        ['sequences/{{basecaller}}/runs/{runname}.{{format}}.gz'.format(runname=runname) for runname in config['runnames']]
    output:
        "sequences/{basecaller, [^.\/]*}/{tag, [^.\/]*}.{format, (fasta|fastq|fa|fq)}.gz"
    shell:
        """
        cat {input} > {output}
        """

# compression
rule basecaller_compress:
    input:
        "{file}.{format}"
    output:
        "{file}.{format, (fasta|fastq|fa|fq)}.gz"
    shell:
        "gzip {input}"

# basecalling QC
rule fastx_stats:
    input:
        "{file}.{format}"
    output:
        temp("{file}.{format, (fasta|fastq|fa|fq)}.qc.tsv")
    params:
        py_bin = lambda wildcards : get_python(wildcards)
    run:
        import rules.utils.basecalling_fastx_stats
        rules.utils.basecalling_fastx_stats.main(input[0], output=output[0])

# report from basecalling
rule basecaller_qc:
    input:
        "{file}.{format}.qc.tsv"
    output:
        "{file}.{format, (fasta|fastq|fa|fq)}.pdf"
    params:
        qc_script = config['bin']['basecalling_qc']
    run:
        import os, subprocess
        input_nrm = os.path.abspath(str(input))
        output_nrm = os.path.abspath(str(output))
        subprocess.run("Rscript -e 'rmarkdown::render(\"{qc_script}\", output_file = \"{output}\")' {input}".format(qc_script=params.qc_script, output=output_nrm, input=input_nrm), check=True, shell=True)
