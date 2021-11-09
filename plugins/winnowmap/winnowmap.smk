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

localrules: meryl_index


rule meryl_index:
    input:
        fasta = "{reference}.{ext}"
    output:
        db = "{reference}.{ext, (fa|fasta)}.meryl",
        kmer_count = "{reference}.{ext, (fa|fasta)}.meryl.txt"
    resources:
        k = config.get('alignment_meryl_k') or 15
    shell:
        """
        {config[plugin/winnowmap/meryl]} count k={k} output {output.db}
        {config[plugin/winnowmap/meryl]} print greater-than distinct=0.9998 {output.db} > {output.kmer_count}
        """

rule winnowmap:
    input:
        sequence = lambda wildcards: get_sequence_batch(wildcards, config),
        reference = lambda wildcards: config['references'][wildcards.reference]['genome'],
        kmer_count = lambda wildcards: config['references'][wildcards.reference]['genome'] + '.meryl.txt'
    output:
        pipe("alignments/winnowmap/{sequence_workflow}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference}.sam")
    threads: config['threads_alignment']
    group: "winnowmap"
    resources:
        threads = lambda wildcards, threads: threads,
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * (config['memory']['winnowmap'][0] + config['memory']['winnowmap'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt * config['runtime']['winnowmap']),   # 60 min / 16 threads
        flags = lambda: config.get("alignment_winnowmap_flags") or "-ax map-ont"
    shell:
        """
        {config[plugin/winnowmap/winnowmap]} {input.reference} {input.sequence} -t {threads} -W {input.kmer_count} {flags} >> {output}
        """
