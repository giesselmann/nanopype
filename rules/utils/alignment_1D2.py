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
import os, sys, re
import argparse
from signal import signal, SIGPIPE, SIG_DFL


# begin/end position tuple with combined difference to each other
class T(tuple):
    def __sub__(self, other):
        return abs(self[1] - other[1]) + abs(self[2] - other[2])

# decode cigar into list of edits
def decodeCigar(cigar):
    ops = [(int(op[:-1]), op[-1]) for op in re.findall('(\d*\D)',cigar)]
    return ops

# return length of recognized operations in decoded cigar
def opsLength(ops, recOps='MIS=X'):
    n = [op[0] for op in ops if op[1] in recOps]
    return sum(n)
    
# main
if __name__ == '__main__':
    signal(SIGPIPE, SIG_DFL) 
    # cmd arguments
    parser = argparse.ArgumentParser(description="Extract template-complement read pairs from 1D2 MinION runs")
    parser.add_argument("--buffer", type=int, default=200, help="length of circular buffer with reads considered")
    parser.add_argument("--tolerance", type=float, default=200, help="Mapping tolerance to consider reads starting at same position")
    args = parser.parse_args()
    # circular buffer for template and complement reads
    template_buffer = []
    complement_buffer = []
    # read first [buffer] lines from stdin
    for i in range(args.buffer):
        try:
            line = next(sys.stdin)
            if line:
                QNAME, FLAG, RNAME, POS, MAPQ, CIGAR = line.strip().split('\t')[:6]
                if not int(FLAG) & 0x4:
                    POS_END = int(POS) + opsLength(decodeCigar(CIGAR), recOps='MDN=X')
                    if int(FLAG) & 0x10:
                        complement_buffer.append(T((RNAME, int(POS), POS_END, QNAME)))
                    else:
                        template_buffer.append(T((RNAME, int(POS), POS_END, QNAME)))
        except StopIteration:
            pass
    # compare input to buffer and write pairs to stdout
    for line in sys.stdin:
        QNAME, FLAG, RNAME, POS, MAPQ, CIGAR = line.strip().split('\t')[:6]
        if not int(FLAG) & 0x4: # ignore unmapped reads
            POS = int(POS)
            POS_END = POS + opsLength(decodeCigar(CIGAR), recOps='MDN=X')
            t0 = T((RNAME, POS, POS_END, QNAME))
            if not int(FLAG) & 0x10:    # template strand
                diffs = [t0 - x for x in complement_buffer]
                if len(diffs) == 0:
                    template_buffer.append(t0)
                    continue
                diff_min = min(diffs)
                if diff_min <= args.tolerance:
                    diff_min_idx = diffs.index(diff_min)
                    t1 = complement_buffer[diff_min_idx]
                    del complement_buffer[diff_min_idx]
                    #print('\t'.join([RNAME, str(POS), str(POS_END), QNAME, str(t1[1]), str(t1[2]), t1[3]]))
                    print('\t'.join([RNAME, str(min(POS, t1[1])), str(max(POS_END, t1[2])), QNAME, t1[3]]))
                else:
                    template_buffer.append(t0)
            else:
                diffs = [t0 - x for x in template_buffer]
                if len(diffs) == 0:
                    complement_buffer.append(t0)
                    continue
                diff_min = min(diffs)
                if diff_min <= args.tolerance:
                    diff_min_idx = diffs.index(diff_min)
                    t1 = template_buffer[diff_min_idx]
                    del template_buffer[diff_min_idx]
                    #print('\t'.join([RNAME, str(t1[1]), str(t1[2]), t1[3], str(POS), str(POS_END), QNAME]))
                    print('\t'.join([RNAME, str(min(POS, t1[1])), str(max(POS_END, t1[2])), t1[3], QNAME]))
                else:
                    complement_buffer.append(t0)
            if len(template_buffer) > args.buffer:
                del template_buffer[:-args.buffer]
            if len(complement_buffer) > args.buffer:
                del complement_buffer[:-args.buffer]
    # buffer not empty but only un-matched reads