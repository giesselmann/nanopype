# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : clean up batch data
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
import os, sys, glob
# local rules
localrules: sequences_clean, alignment_clean, methylation_clean, sv_clean, demux_clean, transcript_isoforms_clean, clean


# remove flag files to force re-run of cleanup
for f in glob.glob('.*.done'):
    os.remove(f)


# clean up compute batches basecalling
rule sequences_clean:
    input:
        [dirpath for dirpath, _, files in os.walk('sequences') if dirpath.endswith('batches')]
    output:
        touch('.basecalling_clean.done')
    shell:
        "rm -r {input}"

# clean up compute batches alignment
rule alignment_clean:
    input:
        [dirpath for dirpath, _, files in os.walk('alignments') if dirpath.endswith('batches')]
    output:
        touch('.alignment_clean.done')
    shell:
        "rm -r {input}"

# clean up compute batches methylation
rule methylation_clean:
    input:
        [dirpath for dirpath, _, files in os.walk('methylation') if dirpath.endswith('batches')]
    output:
        touch('.methylation_clean.done')
    shell:
        "rm -r {input}"

# clean up compute batches sv
rule sv_clean:
    input:
        [dirpath for dirpath, _, files in os.walk('sv') if dirpath.endswith('batches')]
    output:
        touch('.sv_clean.done')
    shell:
        "rm -r {input}"

# clean up compute batches demux
rule demux_clean:
    input:
        [dirpath for dirpath, _, files in os.walk('demux') if dirpath.endswith('batches')]
    output:
        touch('.demux_clean.done')
    shell:
        "rm -r {input}"

# clean up compute batches transcript
rule transcript_isoforms_clean:
    input:
        [dirpath for dirpath, _, files in os.walk('transcript_isoforms') if dirpath.endswith('batches')]
    output:
        touch('.transcript_isoforms_clean.done')
    shell:
        "rm -r {input}"

# clean up everything
rule clean:
    input:
        rules.sequences_clean.output,
        rules.alignment_clean.output,
        rules.methylation_clean.output,
        rules.sv_clean.output,
        rules.demux_clean.output,
        rules.transcript_isoforms_clean.output
    shell:
        "rm {input}"
