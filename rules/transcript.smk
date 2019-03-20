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
from rules.utils.get_file import get_batch_ids_raw
# local rules
# localrules: demux_merge_run


# identify full length cDNA reads
checkpoint pychopper:
    input:
        seq = "sequences/{basecaller}/batches/{batch}.{format}.gz"
        #prmr = ""
    output:
        seq = "sequences/pychopper/{basecaller, [^.\/]*}/batches/{batch, [^.]*}.{format, (fastq|fq)}.gz"
    shadow: "minimal"
    threads: 1
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 4000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt) # 90 min / 16 threads
    singularity:
        "docker://nanopype/transcript:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkfifo input_seq
        mkfifo output_seq
        zcat {input.seq} > input_seq &
        {config[bin_singularity][python]} {config[bin_singularity][cdna_classifier]} -b {input.prmr} input_seq output_seq &
        cat output_seq | gzip > {output.seq}
        """

# spliced alignment to gff
rule spliced_bam2gff:
    input:
        bam = "alignments/{aligner}/{sequence_workflow}/{tag}.{reference}.bam"
    output:
        gff = "transcript_isoforms/pinfish/{aligner, [^.\/]*}/{sequence_workflow, [^.]*}/{tag, [^.\/]*}.{reference, [^.\/]*}.gff"
    threads: config['threads_transcript']
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (8000 + 4000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt) # 90 min / 16 threads
    singularity:
        "docker://nanopype/transcript:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        
        """
