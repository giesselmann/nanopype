# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : Bumblebee methylation calling
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
import os, re
from rules.utils.get_file import get_signal_batch, get_alignment_batch


rule methylation_bumblebee:
    input:
        batch = lambda wildcards : get_signal_batch(wildcards, config),
        run = lambda wildcards : [os.path.join(config['storage_data_raw'], wildcards.runname)] + ([os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn')] if get_signal_batch(wildcards, config).endswith('.txt') else []),
        bam = lambda wildcards : get_alignment_batch(wildcards, config),
        bai = lambda wildcards : get_alignment_batch(wildcards, config) + '.bai',
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    output:
        "methylation/bumblebee/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.\/]*}.tsv.gz"
    shadow: "shallow"
    threads: config['plugin/bumblebee/nproc'] + config['plugin/bumblebee/threads']
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, input, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * 2000 * threads), # 2000
        time_min = lambda wildcards, input, threads, attempt: int((1920 / threads) * attempt)   # 120 min / 16 threads
    params:
        index = lambda wildcards : '--index ' + os.path.join(config['storage_data_raw'], wildcards.runname, 'reads.fofn') if get_signal_batch(wildcards, config).endswith('.txt') else '',
        device = lambda wildcards: '--device ' + str(config['plugin/bumblebee/device']) if 'plugin/bumblebee/device' in config else ''
    shell:
        """
        source {config[plugin/bumblebee/env]}
        mkdir -p raw
        {config[bin][python]} {config[sbin][storage_fast5Index.py]} extract {input.batch} raw/ {params.index} --output_format bulk
        bumblebee modcall {config[plugin/bumblebee/model]} raw/ {input.bam} {input.reference} {params.device} --nproc {config[plugin/bumblebee/nproc]} --threads {config[plugin/bumblebee/threads]} | perl -anle 'print join("\t", @F[0..5], $F[7]-$F[6])' | sort -k1,1 -k2,2n | gzip > {output}
        """
