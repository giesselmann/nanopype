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


# check if tag maps to barcode
def get_tag_barcode(tag, runname, config):
    bc_batches = [None]
    if '__default__' in config['barcodes']:
        bc_batches.extend([config['barcodes']['__default__'][bc] for bc in config['barcodes']['__default__'].keys() if bc in tag])
    elif runname in config['barcodes']:
        bc_batches.extend([config['barcodes'][runname][bc] for bc in config['barcodes'][runname].keys() if bc in tag])
    else:
        pass
    return bc_batches[-1]


# prefix of raw read batches
def get_batch_ids_raw(runname, config, tag=None, checkpoints=None):
    tag_barcode = get_tag_barcode(tag, runname, config) if tag else None
    if tag_barcode and checkpoints:
        barcode_batch_dir = checkpoints.demux_split_barcodes.get(demultiplexer=config['demux_default'], runname=runname).output.barcodes
        barcode_batch = os.path.join(barcode_batch_dir, tag_barcode, '{id}.txt')
        batches_txt, = glob_wildcards(barcode_batch)
        return batches_txt
    else:
        batches_tar, = glob_wildcards("{datadir}/{runname}/reads/{{id}}.tar".format(datadir=config["storage_data_raw"], runname=runname))
        batches_fast5, = glob_wildcards("{datadir}/{runname}/reads/{{id}}.fast5".format(datadir=config["storage_data_raw"], runname=runname))
        return batches_tar + batches_fast5


# get batch of reads as IDs or fast5
def get_signal_batch(wildcards, config):
    raw_dir = config['storage_data_raw']
    if hasattr(wildcards, 'tag'):
        tag_barcode = get_tag_barcode(wildcards.tag, wildcards.runname, config)
        if tag_barcode:
            return os.path.join('demux', config['demux_default'], 'barcodes', wildcards.runname, tag_barcode, wildcards.batch + '.txt')
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
            reference=wildcards.reference)
    return bam
