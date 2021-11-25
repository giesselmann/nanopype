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
import os, sys
from rules.utils.get_file import get_batch_ids_raw, get_signal_batch

# local rules
localrules: basecaller_merge_batches, basecaller_merge_tag


# get batches
def get_batches_basecaller(wildcards):
    return expand("sequences/{sequence_workflow}/batches/{tag}/{runname}/{batch}.fastq.gz",
                        sequence_workflow=wildcards.sequence_workflow,
                        tag=wildcards.tag,
                        runname=wildcards.runname,
                        batch=get_batch_ids_raw(wildcards.runname, config=config, tag=wildcards.tag, checkpoints=checkpoints))

def get_batches_basecaller2(wildcards):
    batches = []
    for runname in config['runnames']:
        batches.extend(
            expand("sequences/{sequence_workflow}/batches/{tag}/{runname}/{batch}.fastq.gz",
                                sequence_workflow=wildcards.sequence_workflow,
                                tag=wildcards.tag,
                                runname=runname,
                                batch=get_batch_ids_raw(runname, config=config, tag=wildcards.tag, checkpoints=checkpoints))
        )
    return batches


# guppy basecalling
rule guppy:
    input:
        batch = lambda wildcards : get_signal_batch(wildcards, config),
        run = lambda wildcards : [os.path.join(config['storage_data_raw'], wildcards.runname)] + ([os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn')] if get_signal_batch(wildcards, config).endswith('.txt') else [])
    output:
        ["sequences/guppy/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.fastq.gz"] +
        ["sequences/guppy/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.sequencing_summary.txt"] +
        (["sequences/guppy/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.hdf5"] if config.get('basecalling_guppy_config') and 'modbases' in config['basecalling_guppy_config'] else [])
    shadow: "shallow"
    threads: config['threads_basecalling']
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['guppy_basecaller'][0] + config['memory']['guppy_basecaller'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt * config['runtime']['guppy_basecaller']), # 90 min / 16 threads
        GPU = 1
    params:
        guppy_config = lambda wildcards : '-c {cfg}{flags}'.format(
                            cfg = config.get('basecalling_guppy_config') or 'dna_r9.4.1_450bps_fast.cfg',
                            flags = ' --fast5_out' if config.get('basecalling_guppy_config') and 'modbases' in config['basecalling_guppy_config'] else ''),
        guppy_server = lambda wildcards, input : '' if (config.get('basecalling_guppy_flags') and '--port' in config['basecalling_guppy_flags']) else '--port ' + config['basecalling_guppy_server'][hash(input.batch) % len(config['basecalling_guppy_server'])] if config.get('basecalling_guppy_server') else '',
        guppy_flags = lambda wildcards : config.get('basecalling_guppy_flags') or '',
        filtering = lambda wildcards : '--qscore_filtering --min_qscore {score}'.format(score = config['basecalling_guppy_qscore_filter']) if config['basecalling_guppy_qscore_filter'] > 0 else '',
        index = lambda wildcards : '--index ' + os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn') if get_signal_batch(wildcards, config).endswith('.txt') else '',
        mod_table = lambda wildcards, input, output : output[2] if len(output) == 3 else ''
    singularity:
        config['singularity_images']['basecalling']
    shell:
        """
        mkdir -p raw
        {config[bin_singularity][python]} {config[sbin_singularity][storage_fast5Index.py]} extract {input.batch} raw/ {params.index} --output_format bulk
        {config[bin_singularity][guppy_basecaller]} -i raw/ --recursive --num_callers 1 --cpu_threads_per_caller {threads} -s workspace/ {params.guppy_config}  {params.filtering} {params.guppy_flags} {params.guppy_server}
        FASTQ_DIR='workspace/pass'
        if [ \'{params.filtering}\' = '' ]; then
            FASTQ_DIR='workspace'
        fi
        find ${{FASTQ_DIR}} -regextype posix-extended -regex '^.*f(ast)?q' -exec cat {{}} \; | gzip > {output[0]}
        find ${{FASTQ_DIR}} -name 'sequencing_summary.txt' -exec mv {{}} {output[1]} \;
        if [ \'{params.mod_table}\' != '' ]; then
            {config[bin_singularity][python]} {config[sbin_singularity][basecalling_guppy_mod.py]} extract `find workspace/ -name '*.fast5'` {params.mod_table}
        fi
        """

# flappie basecalling
rule flappie:
    input:
        batch = lambda wildcards : get_signal_batch(wildcards, config),
        run = lambda wildcards : [os.path.join(config['storage_data_raw'], wildcards.runname)] + ([os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn')] if get_signal_batch(wildcards, config).endswith('.txt') else [])
    output:
        sequence = "sequences/flappie/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.fastq.gz",
        methyl_marks = "sequences/flappie/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.tsv.gz"
    shadow: "shallow"
    threads: config['threads_basecalling']
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['flappie'][0] + config['memory']['flappie'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((5760 / threads) * attempt * config['runtime']['flappie']) # 360 min / 16 threads
    params:
        index = lambda wildcards : '--index ' + os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn') if get_signal_batch(wildcards, config).endswith('.txt') else ''
    singularity:
        config['singularity_images']['basecalling']
    shell:
        """
        export OPENBLAS_NUM_THREADS=1
        mkdir -p raw
        {config[bin_singularity][python]} {config[sbin_singularity][storage_fast5Index.py]} extract {input.batch} raw/ {params.index} --output_format single
        find raw/ -regextype posix-extended -regex '^.*fast5' -type f -exec du -h {{}} + | sort -r -h | cut -f2 > raw.fofn
        split -e -n r/{threads} raw.fofn raw.fofn.part.
        ls raw.fofn.part.* | xargs -n 1 -P {threads} -I {{}} $SHELL -c 'cat {{}} | shuf | xargs -n 1 {config[bin_singularity][flappie]} --model {config[basecalling_flappie_model]} {config[basecalling_flappie_flags]} > raw/{{}}.fastq'
        find ./raw -regextype posix-extended -regex '^.*f(ast)?q' -exec cat {{}} \; > {wildcards.batch}.fq
        cat {wildcards.batch}.fq | {config[bin_singularity][python]} {config[sbin_singularity][methylation_flappie.py]} split methyl_marks.tsv | gzip > {output.sequence}
        cat methyl_marks.tsv | gzip > {output.methyl_marks}
        """

# merge and compression
rule basecaller_merge_batches:
    input:
        lambda wildcards: get_batches_basecaller(wildcards)
    output:
        "sequences/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.fastq.gz"
    run:
        with open(output[0], 'wb') as fp_out:
            for f in input:
                with open(f, 'rb') as fp_in:
                    fp_out.write(fp_in.read())

rule basecaller_merge_tag:
    input:
        lambda wildcards: get_batches_basecaller2(wildcards)
    output:
        "sequences/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.fastq.gz"
    run:
        with open(output[0], 'wb') as fp_out:
            for f in input:
                with open(f, 'rb') as fp_in:
                    fp_out.write(fp_in.read())

rule basecaller_stats:
    input:
        lambda wildcards: get_batches_basecaller(wildcards)
    output:
        "sequences/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.hdf5"
    run:
        import gzip
        import pandas as pd
        def fastq_iter(iterable):
            while True:
                try:
                    title = next(iterable)
                    assert title[0] == '@'
                    seq = next(iterable)
                    _ = next(iterable)
                    qual = next(iterable)
                except StopIteration:
                    return
                mean_q = sum([ord(x) - 33 for x in qual]) / len(qual) if qual else 0.0
                yield len(seq), mean_q
        line_iter = (line for f in input for line in gzip.open(f, 'rb').read().decode('utf-8').split('\n') if line)
        df = pd.DataFrame(fastq_iter(line_iter), columns=['length', 'quality'])
        df.to_hdf(output[0], 'stats')
