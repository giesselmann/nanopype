# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : nanopore demultiplexing rules
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
from rules.utils.get_file import get_batch_ids_raw
# local rules
localrules: demux_split_barcodes

# get batches
def get_batches_demux(wildcards):
    return expand("demux/{demultiplexer}/batches/{runname}/{batch}.tsv",
        demultiplexer=wildcards.demultiplexer,
        runname=wildcards.runname,
        batch=get_batch_ids_raw(wildcards.runname, config=config))


# deepbinner demux
rule deepbinner:
    input:
        signal = lambda wildcards : get_signal_batch(wildcards, config),
        model = lambda wildcards : config["deepbinner_models"][get_kit(wildcards)] if get_kit(wildcards, config) in config["deepbinner_models"] else config["deepbinner_models"]['default']
    output:
        "demux/deepbinner/batches/{runname, [^.\/]*}/{batch, [^.\/]*}.tsv"
    shadow: "minimal"
    threads: config['threads_demux']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['deepbinner'][0] + config['memory']['deepbinner'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt * config['runtime']['deepbinner']) # 60 min / 16 threads
    singularity:
        "docker://nanopype/demux:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkdir -p raw
        {config[bin][python]} {config[sbin][storage_fast5Index.py]} extract {input.signal} raw/ --output_format single
        {config[bin_singularity][python]} {config[bin_singularity][deepbinner]} classify raw -s {input.model} --intra_op_parallelism_threads {threads} --omp_num_threads {threads} --inter_op_parallelism_threads {threads} | tail -n +2 > {output}
        """

# split into barcode id list per run
checkpoint demux_split_barcodes:
    input:
        batches = lambda wildcards: get_batches_demux(wildcards)
    output:
        barcodes = directory("demux/{demultiplexer, [^.\/]*}/barcodes/{runname}/")
    singularity:
        "docker://nanopype/demux:{tag}".format(tag=config['version']['tag'])
    run:
        import os, itertools, collections
        os.makedirs(output.barcodes, exist_ok=True)
        barcode_ids = collections.defaultdict(list)
        for f in input.batches:
            read_barcodes = []
            with open(f, 'r') as fp:
                read_barcodes = [tuple(line.split('\t')) for line in fp.read().split('\n') if line]
            read_barcodes.sort(key=lambda x : x[1])
            for bc, ids in itertools.groupby(read_barcodes, key=lambda x:x[1]):
                barcode_ids[bc].extend([id for id, barcode in ids])
        def chunked(l, n):
            for i in range(0, len(l), n):
                yield l[i:i + n]
        for barcode, ids in barcode_ids.items():
            os.mkdir(os.path.join(output.barcodes, barcode))
            for i, batch in enumerate(chunked(ids, config['demux_batch_size'])):
                with open(os.path.join(output.barcodes, barcode, str(i) + '.txt'), 'w') as fp:
                    print('\n'.join(batch), file=fp)
