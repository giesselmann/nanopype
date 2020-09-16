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
import sys, re
import argparse
import pandas as pd
from signal import signal, SIGPIPE, SIG_DFL




# helper
# decode cigar into list of edits
def decodeCigar(cigar):
    ops = [(int(op[:-1]), op[-1]) for op in re.findall('(\d*\D)',cigar) if op[:-1]]
    return ops




# return length of recognized operations in decoded cigar
def opsLength(ops, recOps='MIS=X'):
    n = [op[0] for op in ops if op[1] in recOps]
    return sum(n)




if __name__ == '__main__':
    signal(SIGPIPE,SIG_DFL)
    # cmd arguments
    parser = argparse.ArgumentParser(description="Compute summary from alignments")
    parser.add_argument("output", help="output file")
    args = parser.parse_args()
    def sam_parser(iterable):
        while True:
            try:
                line = next(iterable)
            except StopIteration:
                return
            fields = line.strip().split('\t')
            opt_fields = [tuple(x.split(':')) for x in fields[11:]]
            opt_nm = [f[2] for f in opt_fields if f[0] == 'NM']
            cigar = fields[5]
            length = opsLength(decodeCigar(cigar), recOps='MIS=X') if cigar != "*" else len(fields[9]) if fields[9] != "*" else 0
            mapped_length = opsLength(decodeCigar(cigar), recOps='MI=X') if cigar != "*" else 0
            if opt_nm:
                nm = int(opt_nm[0])
                blast_identity = ((mapped_length-nm)/float(mapped_length)) if mapped_length > 0 else 0.0
                yield fields[0], int(fields[1]), length, mapped_length, blast_identity
            else:
                yield fields[0], int(fields[1]), length, mapped_length
    record_iter = (line for line in sys.stdin if not line.startswith('@'))
    stat_iter = (sam_parser(record_iter))
    df = pd.DataFrame(stat_iter)
    if df.shape[1] == 2:
        df.columns = ['ID', 'flag', 'length', 'mapped_length']
        df = df.astype({'ID': 'object', 'flag': 'int32', 'length': 'int32', 'mapped_length': 'int32'})
    else:
        df.columns = ['ID', 'flag', 'length', 'mapped_length', 'identity']
        df = df.astype({'ID': 'object', 'flag': 'int32', 'length': 'int32', 'mapped_length': 'int32', 'identity': 'float32'})
    df.to_hdf(args.output, 'stats')
