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
from .storage import get_kit

# prefix of raw read batches
def get_batch_ids_raw(runname, config):
    batches_tar, = glob_wildcards("{datadir}/{runname}/reads/{{id}}.tar".format(datadir=config["storage_data_raw"], runname=runname))
    batches_fast5, = glob_wildcards("{datadir}/{runname}/reads/{{id}}.fast5".format(datadir=config["storage_data_raw"], runname=runname))
    return batches_tar + batches_fast5

# get type of fast5 batch from basename
def get_batch_ext(wildcards, config):
    raw_prefix = "{datadir}/{wildcards.runname}/reads/{wildcards.batch}".format(datadir=config["storage_data_raw"], wildcards=wildcards)
    # TODO idx prefix
    if os.path.isfile(raw_prefix + ".tar"):
        return "tar"
    elif os.path.isfile(raw_prefix + ".fast5"):
        return "fast5"
    else:
        pass

def get_signal_batch(wildcards, config):
    raw_dir = config['storage_data_raw']
    batch_file = os.path.join(raw_dir, wildcards.runname, 'reads', wildcards.batch)
    if os.path.isfile(batch_file + '.tar'):
        return batch_file + '.tar'
    elif os.path.isfile(batch_file + '.fast5'):
        return batch_file + '.fast5'
    else:
        return []

# get available batch sequence
def get_sequence_batch(wildcards, config):
    base = "sequences/{sequence_workflow}/batches/{tag}/{runname}/{batch}".format(
            sequence_workflow=wildcards.sequence_workflow,
            tag=wildcards.tag,
            runname=wildcards.runname,
            batch=wildcards.batch)
    extensions = ['.fa', '.fasta', '.fq', '.fastq']
    for ext in extensions:
        if os.path.isfile(base + ext + '.gz') or os.path.isfile(base + ext):
            return base + ext + '.gz'
    return base + '.fastq.gz'

# get alignment batch with default basecaller and aligner
def get_alignment_batch(wildcards, config):
    bam = "alignments/{aligner}/{sequence_workflow}/batches/{tag}/{runname}/{batch}.{reference}.bam".format(
            aligner=wildcards.aligner,
            sequence_workflow=wildcards.sequence_workflow,
            tag=wildcards.tag,
            runname=wildcards.runname,
            batch=wildcards.batch,
            reference=wildcards.reference
            )
    return bam
