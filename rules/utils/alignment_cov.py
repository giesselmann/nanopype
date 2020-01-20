# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : 1D2 read matching
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
import os, sys, re
import argparse
import numpy as np
from itertools import groupby
from tqdm import tqdm
from signal import signal, SIGPIPE, SIG_DFL




# main
if __name__ == '__main__':
    signal(SIGPIPE, SIG_DFL)
    # cmd arguments
    parser = argparse.ArgumentParser(description="Compute genome wide coverage")
    parser.add_argument("chr_sizes", help="chromosome sizes")
    args = parser.parse_args()
    chr_dict = {}

    with open(args.chr_sizes, 'r') as fp:
        for line in fp:
            chr, len_str = line.strip().split('\t')
            chr_dict[chr] = np.zeros(int(len_str), dtype=np.int32)

    for line in tqdm(sys.stdin):
        chr, begin, end, _ = line.split('\t', 3)
        chr_dict[chr][int(begin):int(end)] += 1

    for key in sorted(chr_dict.keys()):
        offset = 0
        for k, g in groupby(chr_dict[key]):
            l = len(list(g))
            print("\t".join([key, str(offset), str(offset+l), str(k)]))
            offset += l
