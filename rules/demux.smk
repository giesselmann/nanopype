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
localrules: deepbinner_barcode, guppy_barcode

# get batches
def get_batches_demux(wildcards):
    return expand("demux/{demultiplexer}/batches/{runname}/{batch}.tsv",
        demultiplexer=wildcards.demultiplexer,
        runname=wildcards.runname,
        batch=get_batch_ids_raw(wildcards.runname, config=config))

def get_batches_demux_seq(wildcards):
    return expand("sequences/{sequence_workflow}/batches/{tag}/{runname}/{batch}.fastq.gz",
        sequence_workflow=config['demux_seq_workflow'],
        tag=config['demux_seq_tag'] if 'demux_seq_tag' in config and config['demux_seq_tag'] else "default",
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

checkpoint guppy_barcode_batches:
    input:
        sequences = lambda wildcards: get_batches_demux_seq(wildcards)
    output:
        batches = directory("demux/guppy/batches/{runname}")
    threads: config['threads_demux']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['guppy_barcoder'][0] + config['memory']['guppy_barcoder'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt * config['runtime']['guppy_barcoder']) # 60 min / 16 threads
    params:
        seq_dir = lambda wildcards, input : os.path.dirname(input.sequences[0])
    singularity:
        "docker://nanopype/basecalling:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][guppy_barcoder]} -i {params.seq_dir} -s {output.batches} -t {threads} -q {config[demux_batch_size]} --compress_fastq --barcode_kits {config[demux_guppy_kits]}
        """

checkpoint guppy_barcode:
    input:
        sequences = lambda wildcards: get_batches_demux_seq(wildcards),
        batches = "demux/guppy/batches/{runname}"
    output:
        barcodes = directory("demux/guppy/barcodes/{runname}")
    threads: config['threads_demux']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['guppy_barcoder'][0] + config['memory']['guppy_barcoder'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt * config['runtime']['guppy_barcoder']) # 60 min / 16 threads
    params:
        seq_dir = lambda wildcards, input : os.path.dirname(input.sequences[0])
    run:
        import os, gzip, re
        import shutil
        import itertools
        barcodes = [f.name for f in os.scandir(input.batches) if f.is_dir()]
        def fastq_ID(iterable):
            fq_iter = itertools.islice(iterable, 0, None, 4)
            while True:
                header = next(fq_iter).decode('utf-8')
                yield header[1:].split()[0]
        def touch(fname, times=None):
            with open(fname, 'a'):
                os.utime(fname, times)
        for barcode in barcodes:
            os.makedirs(os.path.join(output.barcodes, barcode), exist_ok=True)
            batches = [f.name for f in os.scandir(os.path.join(input.batches, barcode)) if f.name.endswith('fastq.gz')]
            for batch in batches:
                # read IDs from fastq stream
                batch_file = os.path.join(input.batches, barcode, batch)
                IDs = []
                with gzip.open(batch_file, 'rb') as fp:
                    IDs = [ID for ID in fastq_ID(fp)]
                # write IDs to batch file
                with open(os.path.join(output.barcodes, barcode, re.sub('fastq\.gz', 'txt', batch)), 'w') as fp:
                    fp.write('\n'.join(IDs))
            # move fastq to sequences directory
            bc_map = (config['barcodes'][wildcards.runname] if wildcards.runname in config['barcodes'] else
                     config['barcodes']['__default__'] if '__default__' in config['barcodes'] else
                     {})
            bc_tags = [key for key, value in bc_map.items() if value == barcode]
            # move if one target tag
            if len(bc_tags) == 1:
                target_path = os.path.join('sequences', config['demux_seq_workflow'], 'batches',
                              (config['demux_seq_tag'] if 'demux_seq_tag' in config else 'default') + '.' + bc_tags[0],
                             wildcards.runname)
                shutil.move(os.path.join('demux', 'guppy', 'batches', wildcards.runname, barcode),
                            target_path)
                # touch sequences after creating batch ID files
                for f in os.scandir(target_path):
                    if f.name.endswith('fastq.gz'):
                        touch(f.path)
            # copy if multiple tags per barcode
            elif len(bc_tags) > 1:
                for bc_tag in bc_tags:
                    target_path = os.path.join('sequences', config['demux_seq_workflow'], 'batches',
                    (config['demux_seq_tag'] if 'demux_seq_tag' in config else 'default') + '.' + bc_tags[0],
                    wildcards.runname)
                    if os.path.exists(target_path):
                        shutil.rmtree(target_path)
                    shutil.copytree(os.path.join('demux', 'guppy', 'batches', wildcards.runname, barcode),
                                    target_path)

# split into barcode id list per run
checkpoint deepbinner_barcode:
    input:
        batches = lambda wildcards: get_batches_demux(wildcards)
    output:
        barcodes = directory("demux/deepbinner/barcodes/{runname}/")
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
