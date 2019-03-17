# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : nanopore transcript rules
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
# localrules: demux_merge_run


# identify full length cDNA reads
rule pychopper:
    input:
        "sequences/{basecaller}/runs/{runname}/{batch}.{format}.gz"
    output:
        "transcript/pychopper/{basecaller, [^.\/]*}/runs/{runname, [^.\/]*}/{batch, [^.]*}.{format, (fastq|fq)}.gz"
    shadow: "minimal"
    threads: config['threads_transcript_batch']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 4000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt) # 90 min / 16 threads
    singularity:
        "docker://nanopype/transcript:{tag}".format(tag=config['version']['tag'])
    shell:
        """

        """

# splice alignment
rule minimap2_splice:
    input:
        sequence = lambda wildcards: get_sequence_batch(wildcards, config),
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    output:
        pipe("alignments/minimap2/{basecaller, [^.\/]*}/runs/{runname, [^.\/]*}/{batch, [^.\/]*}.{reference}.sam")
    threads: config['threads_alignment']
    group: "minimap2"
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.2 * (attempt - 1))) * (8000 + 500 * threads)),
        time_min = lambda wildcards, threads, attempt: int((960 / threads) * attempt)   # 60 min / 16 threads
    singularity:
        "docker://nanopype/transcript:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        {config[bin_singularity][minimap2]} {config[transcript_minimap2_flags]} {input.reference} {input.sequence} -t {threads} >> {output}
        """
