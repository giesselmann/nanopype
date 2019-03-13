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
from rules.utils.get_file import get_batches
# local rules
localrules: demux_merge_run

# get batches
def get_batches_demux(wildcards):
    return expand("demux/{wildcards.demultiplexer}/{wildcards.runname}/{{batch}}.tsv".format(wildcards=wildcards), batch=get_batches(wildcards, config=config))

# deepbinner demux
rule deepbinner:
    input:
        signals = lambda wildcards : "{data_raw}/{{runname}}/reads/{{batch}}.{ext}".format(data_raw = config["storage_data_raw"], ext=get_batch_ext(wildcards, config)),
        model = lambda wildcards : config["deepbinner_models"][get_kit(wildcards)] if get_kit(wildcards, config) in config["deepbinner_models"] else config["deepbinner_models"]['default']
    output:
        "demux/deepbinner/{runname, [^.\/]*}/{batch, [^.\/]*}.tsv"
    shadow: "minimal"
    threads: config['threads_demux']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (4000 + 1000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt) # 60 min / 16 threads
    params:
        batch_base = lambda wildcards : os.path.join(config['storage_data_raw'], 'reads', wildcards.runname)
    singularity:
        "docker://nanopype/demux:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkdir -p raw
        {config[sbin_singularity][storage_batch2fast5.sh]} {input.signals} {params.batch_base} raw/ {config[sbin_singularity][base]} {config[bin_singularity][python]}
        {config[bin_singularity][python]} {config[bin_singularity][deepbinner]} classify raw -s {input.model} --intra_op_parallelism_threads {threads} --omp_num_threads {threads} --inter_op_parallelism_threads {threads} | tail -n +2 > {output}
        """

# merge and compression
rule demux_merge_run:
    input:
        get_batches_demux
    output:
        "demux/{demultiplexer, [^.\/]*}/{runname, [^.\/]*}.tsv"
    singularity:
        "docker://nanopype/demux:{tag}".format(tag=config['version']['tag'])
    shell:
        "cat {input} > {output}"
