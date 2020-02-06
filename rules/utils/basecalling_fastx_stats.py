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
import os, sys, argparse
import gzip, json
from collections import OrderedDict


# parse header lines of format
# @a7dea3e9-3704-4eef-91db-d601a5f6f176 runid=0a37ba72f079fbc7f7e52f3f0ff3720d72ae50ed read=1007 ch=202 start_time=2017-09-07T11:57:42Z
def parse_name(name):
    if ' ' in name:
        ID, attr_str = name.split(' ', 1)
        ID = ID[1:]
        attrs = OrderedDict()
        attr_str = attr_str.strip()
        # value=pattern
        if not '{' in attr_str:
            fields = attr_str.split(' ')
            attrs.update([tuple(field.split('=')) for field in fields])
        # json pattern
        elif attr_str[0] == '{' and attr_str[-1] == '}':
            attrs.update(json.loads(attr_str))
        return ID, attrs
    else:
        return name[1:]
    

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
            elif line[0] == '>':      # fasta
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
                yield name, sequence, None, None, attrs
        if line is None:
            return

            
def main(fx, output=sys.stdout):
    f_open_in = gzip.GzipFile if os.path.splitext(fx)[1] == '.gz' else open
    f_open_out = lambda output, *args : open(output, *args) if isinstance(output, str) else sys.stdout 
    header = ['ID', 'length']
    # check format and parse first record
    with f_open_in(fx, 'rb') as fp:
        name, sequence, comment, quality, attrs = next(fastqIter(fp))
        if quality:
            header += ['mean_q']
        for key, value in attrs.items():
            header += [key]
    with f_open_out(output, 'w') as fp:
        print('\t'.join(header), file=fp)
    # parse entire file
    with f_open_in(fx, 'rb') as fp_in, f_open_out(output, 'a') as fp_out:
        for name, sequence, comment, quality, attrs in fastqIter(fp_in):
            mean_q = 0
            fields = [name, str(len(sequence))]
            if quality:
                mean_q = sum([ord(x) - 33 for x in quality]) / len(quality)
                fields.append(str(mean_q))
            fields += [str(value) for value in attrs.values()]
            print('\t'.join(fields), file=fp_out)

            
if __name__ == '__main__':
    # cmd arguments            
    parser = argparse.ArgumentParser(description="Compute per read stats of fasta/fastq")
    parser.add_argument("fx", help="Path to input fasta/fastq file")
    args = parser.parse_args()
    main(args.fx)

    