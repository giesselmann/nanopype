# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : get file helper
#
#  DESCRIPTION   : none
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
import os
from snakemake.io import glob_wildcards


# batches of packed fast5 files
def get_batches(wildcards, config):
    batches, = glob_wildcards("{datadir}/{wildcards.runname}/reads/{{id}}.tar".format(datadir=config["storage_data_raw"], wildcards=wildcards))
    return batches

# get available batch sequence
def get_sequence_batch(wildcards, config, force_basecaller=None):
    if force_basecaller:
        basecaller = force_basecaller
    elif hasattr(wildcards, 'basecaller'):
        basecaller = wildcards.basecaller
    else:
        basecaller = config['basecalling_default']
    base = "sequences/{basecaller}/runs/{wildcards.runname}/{wildcards.batch}".format(wildcards=wildcards, basecaller=basecaller)
    extensions = ['.fa', '.fasta', '.fq', '.fastq']
    for ext in extensions:
        if os.path.isfile(base + ext + '.gz') or os.path.isfile(base + ext):
            return base + ext + '.gz'
    return base + '.fastq.gz'
    
# get available merged sequence 
def get_sequence(wildcards, config, force_basecaller=None):
    if force_basecaller:
        basecaller = force_basecaller
    elif hasattr(wildcards, 'basecaller'):
        basecaller = wildcards.basecaller
    else:
        basecaller = config['basecalling_default']
    if hasattr(wildcards, 'runname') and wildcards.runname:
        base = "sequences/{basecaller}/runs/{wildcards.runname}".format(wildcards=wildcards, basecaller=basecaller)
    else:
        base = "sequences/{basecaller}/{wildcards.tag}".format(wildcards=wildcards, basecaller=basecaller)
    extensions = ['.fa', '.fasta', '.fq', '.fastq']
    for ext in extensions:
        if os.path.isfile(base + ext + '.gz'):
            return base + ext + '.gz'
    return base + '.fastq.gz'
    
# get alignment batch with default basecaller and aligner
def get_alignment_batch(wildcards, config, force_basecaller=None, force_aligner=None):
    if force_basecaller:
        basecaller = force_basecaller
    elif hasattr(wildcards, 'basecaller'):
        basecaller = wildcards.basecaller
    else:
        basecaller = config['basecalling_default']
    if force_aligner:
        aligner = force_aligner
    elif hasattr(wildcards, 'aligner'):
        aligner = wildcards.aligner
    else:
        aligner = config['alignment_default']
    bam = "alignments/{aligner}/{basecaller}/runs/{wildcards.runname}/{wildcards.batch}.{wildcards.reference}.bam".format(wildcards=wildcards, basecaller=basecaller, aligner=aligner)
    return bam

# get alignment with default basecaller and aligner
def get_alignment(wildcards, config, force_basecaller=None, force_aligner=None):
    if force_basecaller:
        basecaller = force_basecaller
    elif hasattr(wildcards, 'basecaller'):
        basecaller = wildcards.basecaller
    else:
        basecaller = config['basecalling_default']
    if force_aligner:
        aligner = force_aligner
    elif hasattr(wildcards, 'aligner'):
        aligner = wildcards.aligner
    else:
        aligner = config['alignment_default']
    bam = "alignments/{aligner}/{basecaller}/{wildcards.tag}.{wildcards.reference}.bam".format(wildcards=wildcards, basecaller=basecaller, aligner=aligner)
    return bam
