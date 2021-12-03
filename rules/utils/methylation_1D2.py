# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : 1D2 read matched single read methylation
#
#  DESCRIPTION   : none
#
#  RESTRICTIONS  : none
#
#  REQUIRES      : none
#
# ---------------------------------------------------------------------------------
# Copyright (c) 2018-2021, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
import os, sys, re
import gzip
import argparse


# iterate bed-6 single read methylation values
def value_iter(iterable):
    iterable = iter(iterable)
    try:
        line = next(iterable).decode('utf-8')
    except StopIteration:
        return
    values = []
    values_chr = ''
    values_name = ''
    while line:
        chr, begin, end, name, value, strand = line.strip().split('\t')[:6]
        if name != values_name and values:
            yield values_chr, values_name, values
            values = []
        values.append((chr, begin, end, value, strand))
        values_chr = chr
        values_name = name
        try:
            line = next(iterable).decode('utf-8')
        except StopIteration:
            line = None
    if values:
        yield values_chr, values_name, values


# main
if __name__ == '__main__':
    # cmd arguments
    parser = argparse.ArgumentParser(description="1D2 read matched single read methylation")
    parser.add_argument("pairs", help="1D2 read matches")
    parser.add_argument("values", help="Single read methylation table")
    args = parser.parse_args()
    # load read pair table
    read_pairs = {}
    with open(args.pairs, 'r') as fp_in:
        for line in fp_in:
            chr, begin, end, n0, n1 = line.strip().split('\t')
            if chr not in read_pairs:
                read_pairs[chr] = []
            read_pairs[chr].append((begin, end, n0, n1))

    # load methylation values chromosome wise
    current_chr = ''
    current_values = {}
    f_open = gzip.GzipFile if os.path.splitext(args.values)[1] == '.gz' else open
    with f_open(args.values, 'rb') as fp_in:
        for value_chr, value_name, values in value_iter(fp_in):
            if value_chr == current_chr or len(current_values) == 0:
                current_values[value_name] = values
                current_chr = value_chr
            else:
                assert current_chr in read_pairs
                current_pairs = read_pairs[current_chr]
                # print("pairs:", str(len(current_pairs)), file=sys.stderr)
                # print("values:", str(len(current_values)), file=sys.stderr)
                for pair_begin, pair_end, n0, n1 in current_pairs:
                    # print(n0, n1, file=sys.stderr)
                    # assert n0 in current_values
                    # assert n1 in current_values
                    if n0 not in current_values or n1 not in current_values:
                        continue
                    v0 = {(chr, begin, end):(value, strand) for chr, begin, end, value, strand in current_values[n0] if begin >= pair_begin and end <= pair_end}
                    v1 = {(chr, begin, end):(value, strand) for chr, begin, end, value, strand in current_values[n1] if begin >= pair_begin and end <= pair_end}
                    # only print matching positions
                    v01 = sorted(list(set(v0.keys()) & set(v1.keys())), key = lambda x: x[1])
                    for v in v01:
                        d0 = v0[v]
                        d1 = v1[v]
                        print('\t'.join(list(v) + [n0, d0[0], n1, d1[0]]))
                current_values = {}