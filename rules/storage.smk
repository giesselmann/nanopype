# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : Raw data storage, indexing, extraction etc.
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
from rules.utils.get_file import get_batch_ids_raw
# local rules
localrules: storage_index_run, storage_extract
# fast5 signal location
LOC_RAW = "/Raw/"

def get_batches_indexing(wildcards):
    return expand("{data_raw}/{runname}/reads/{batch}.fofn",
        data_raw = config["storage_data_raw"],
        runname=wildcards.runname,
        batch=get_batch_ids_raw(wildcards, config=config))

# extract read ID from individual fast5 files
rule storage_index_batch:
    input:
        batch = lambda wildcards : get_signal_batch(wildcards, config)
    output:
        temp("{data_raw}/{{runname, [^.\/]*}}/reads/{{batch}}.fofn".format(data_raw = config["storage_data_raw"]))
    shadow: "shallow"
    threads: 1
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.1 * (attempt - 1))) * 4000),
        time_min = 15
    shell:
        """
        {config[bin][python]} {config[sbin][storage_fast5Index.py]} index {input.batch} --out_prefix reads --tmp_prefix $(pwd) > {output}
        """

# merge batch indices
rule storage_index_run:
    input:
        batches = get_batches_indexing
    output:
        fofn = "{data_raw}/{{runname, [^.\/]*}}/reads.fofn".format(data_raw = config["storage_data_raw"])
    run:
        with open(output[0], 'w') as fp:
            for f in input.batches:
                print(open(f, 'r').read(), end='', file=fp)

 # index multiple runs
rule storage_index_runs:
    input:
        files = lambda wildcards : ["{data_raw}/{runname}/reads.fofn".format(data_raw = config["storage_data_raw"], runname=rn) for rn in config['runnames']]


# extract reads from indexed run
rule storage_extract:
    input:
        index = "{data_raw}/{{runname}}/reads.fofn".format(data_raw = config["storage_data_raw"]),
        names = "subset/{tag}.txt"
    output:
        directory("subset/{tag, [^.\/]*}/{runname, [^.\/]*}")
    shell:
        """
        mkdir -p {output}
        {config[bin][python]} {config[sbin][storage_fast5Index.py]} extract {input.names} {output} --index {input.index} --output_format bulk
        """


# extract reads from indexed runs
rule storage_extract_multi:
    input:
        names = "subset/{tag}.txt",
        files = lambda wildcards : [directory("subset/{tag}/{runname}".format(tag=wildcards.tag, runname=rn)) for rn in config['runnames']]
    output:
        touch("subset/{tag}.done")
    run:
        print(input.files)
