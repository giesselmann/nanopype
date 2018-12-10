# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : qc helper
#
#  DESCRIPTION   : none
#
#  RESTRICTIONS  : none
#
#  REQUIRES      : none
#
# ---------------------------------------------------------------------------------
# Copyright (c) 2018,  Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
import os, sys, argparse
import gzip
from collections import OrderedDict


# parse header lines of format
# @a7dea3e9-3704-4eef-91db-d601a5f6f176 runid=0a37ba72f079fbc7f7e52f3f0ff3720d72ae50ed read=1007 ch=202 start_time=2017-09-07T11:57:42Z
def parse_name(name):
    fields = name.split(' ')
    ID = fields[0][1:]
    attrs = OrderedDict()
    if len(fields) > 1:  
        attrs.update([tuple(field.split('=')) for field in fields[1:]])
    return ID, attrs
    

# fastq/fasta iterator
def fastqIter(iterable):
    it = iter(iterable)
    line = next(it).decode('utf-8').strip()
    while True:
        if line is not None and len(line) > 0:
            if line[0] == '@':      # fastq
                name, attrs = parse_name(line)
                sequence = next(it).decode('utf-8').strip()
                comment = next(it).decode('utf-8').strip()
                quality = next(it).decode('utf-8').strip()
                yield name, sequence, comment, quality, attrs
                line = next(it).decode('utf-8').strip()
            if line[0] == '>':      # fasta
                name, attrs = parse_name(line)
                sequence = next(it).decode('utf-8').strip()
                try:
                    line = next(it).decode('utf-8').strip()
                    while line is not None and len(line) > 0 and line[0] != '>' and line[0] != '@':
                        sequence += line
                        line = next(it).decode('utf-8').strip()
                except StopIteration:
                    yield name, sequence, None, None, attrs
                    raise
        if line is None:
            return


if __name__ == '__main__':
    # cmd arguments            
    parser = argparse.ArgumentParser(description="Compute per read stats of fasta/fastq")
    parser.add_argument("fx", help="Path to input fasta/fastq file")
    args = parser.parse_args()
    
    f_open = gzip.GzipFile if os.path.splitext(args.fx)[1] == '.gz' else open
    header = ['ID', 'length']
    # check format and parse first record
    with f_open(args.fx, 'rb') as fp:
        name, sequence, comment, quality, attrs = next(fastqIter(fp))
        if quality:
            header += ['mean_q']
        for key, value in attrs.items():
            header += [key]
    print('\t'.join(header))
    # parse entire file    
    with f_open(args.fx, 'rb') as fp:
        for name, sequence, comment, quality, attrs in fastqIter(fp):
            mean_q = 0
            if quality:
                mean_q = sum([ord(x) - 33 for x in quality]) / len(quality)
            print('\t'.join([name, str(len(sequence)), str(mean_q)] + list(attrs.values())))
    