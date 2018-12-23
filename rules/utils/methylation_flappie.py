# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : flappie methylation calling related helper
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
import os, sys, re
import gzip
import argparse
import numpy as np
from signal import signal, SIGPIPE, SIG_DFL


# parse fasta/fastq
def fastxIter(iterable):
    it = iter(iterable)
    next_decode = lambda *args: next(*args).decode('utf-8').strip()
    line = next_decode(it)
    while True:
        if line is not None and len(line) > 0:
            if line[0] == '@':      # fastq
                name = line[1:].split()[0]
                sequence = next_decode(it)
                comment = next_decode(it)
                quality = next_decode(it)
                yield name, sequence
                line = next_decode(it)
            if line[0] == '>':      # fasta
                name = line[1:]
                sequence = next_decode(it)
                try:
                    line = next_decode(it)
                except StopIteration:
                    yield name, sequence.upper()
                    return
                while line is not None and len(line) > 0 and line[0] != '>' and line[0] != '@':
                    sequence += line
                    try:
                        line = next_decode(it).strip()
                    except StopIteration:
                        yield name, sequence.upper()
                        return
                yield name, sequence.upper()
        if line is None:
            raise StopIteration()


# parse base modification from read sequence with reference and position
class seq_mod():
    def __init__(self, ref_file, read_file, ref_regex='CG', mod_regex='ZG'):
        ref = {}
        f_open = gzip.GzipFile if os.path.splitext(ref_file)[1] == '.gz' else open
        with f_open(ref_file, 'rb') as fp:
            ref = {name:sequence.upper() for name, sequence in fastxIter(fp)}
        self.ref = ref
        reads = {}
        f_open = gzip.GzipFile if os.path.splitext(read_file)[1] == '.gz' else open
        with f_open(read_file, 'rb') as fp:
            reads = {name:sequence.upper() for name, sequence in fastxIter(fp)}
        self.reads = reads
        self.ref_regex = re.compile(ref_regex)
        self.mod_regex = re.compile(mod_regex)

    # decode cigar into list of edits
    def __decodeCigar__(self, cigar):
        ops = [(int(op[:-1]), op[-1]) for op in re.findall('(\d*\D)',cigar)]
        return ops

    # return length of recognized operations in decoded cigar
    def __opsLength__(self, ops, recOps='MIS=X'):
        n = [op[0] for op in ops if op[1] in recOps]
        return sum(n)

    def annotate(self, qname, cigar, flag, rname, pos):
        res = []
        if qname in self.reads and rname in self.ref:
            # parse cigar
            dec_cigar = self.__decodeCigar__(cigar)
            ref_len = self.__opsLength__(dec_cigar, recOps='MDN=X')
            read_clip_begin = sum([x[0] for x in dec_cigar[:2] if x[1] in 'ISH'])
            read_clip_end = sum([x[0] for x in dec_cigar[-2:] if x[1] in 'ISH'])
            # matching ref and read slices
            ref_slice = self.ref[rname][pos - 1 : pos + ref_len - 1]
            if flag & 0x16:
                read_slice = self.reads[qname][read_clip_end : -read_clip_begin]
                strand = '-'
            else:
                read_slice = self.reads[qname][read_clip_begin : -read_clip_end]
                strand = '+'
            # expand ref to read
            flatten = lambda l: [item for sublist in l for item in sublist]
            read_mask = np.array(flatten([[True]*l if op in 'M=X' else [False]*l if op in 'I' else [] for l, op in dec_cigar]))
            ref_mask = np.array(flatten([[True]*l if op in 'M=X' else [False]*l if op in 'D' else [] for l, op in dec_cigar]))
            ref_seq = np.array(['-'] * len(read_mask))
            ref_seq[read_mask] = np.array([c for c in ref_slice])[ref_mask]
            ref_seq = ''.join(ref_seq)
            ref_pos = np.zeros(len(read_mask), dtype=int)
            ref_pos[read_mask] = pos + np.cumsum(read_mask)[read_mask]
            # reverse complement ref sequence for complement reads
            complement = lambda s, cmp={'A':'T','T':'A','C':'G','G':'C'}:''.join([cmp[t] if t in cmp else '-' for t in s])
            if flag & 0x16:
                ref_seq = complement(ref_seq)[::-1]
                ref_pos = ref_pos[::-1]
            # search pattern on reference, check value in read
            for ref_match in self.ref_regex.finditer(ref_seq):
                ref_match_temp_begin = ref_pos[min(ref_match.start(), ref_match.end())]
                ref_match_temp_end = ref_pos[max(ref_match.start(), ref_match.end())]
                ref_match_seq = ref_seq[ref_match.start():ref_match.end()]
                read_match_seq = read_slice[ref_match.start():ref_match.end()]
                if len(ref_match_seq) != ref_match_temp_end - ref_match_temp_begin:
                    continue
                read_mod_match = self.mod_regex.fullmatch(read_match_seq)
                read_base_match = self.ref_regex.fullmatch(read_match_seq)
                if read_mod_match:
                    value = '1'
                elif read_base_match:
                    value = '0'
                if read_mod_match or read_base_match:
                    print('\t'.join([rname, str(ref_match_temp_begin), str(ref_match_temp_end), qname, value, strand]))

        return res


if __name__ == '__main__':
    signal(SIGPIPE,SIG_DFL)
    parser = argparse.ArgumentParser(description="Flappie methylation sequence to table format conversion")
    parser.add_argument("reference", help="Reference sequence")
    parser.add_argument("sequences", help="Sequence input in fastq/fasta")
    parser.add_argument("--ref_regex", default="CG", help="Reference sequence pattern")
    parser.add_argument("--mod_regex", default="ZG", help="Modification sequence pattern")
    args = parser.parse_args()
    # init
    mod = seq_mod(args.reference, args.sequences, args.ref_regex, args.mod_regex)
    # read sam formated input from stdin
    for line in sys.stdin:
        fields = line.strip().split('\t')
        QNAME, FLAG, RNAME, POS, _, CIGAR = fields[:6]
        mod.annotate(QNAME, CIGAR, int(FLAG), RNAME, int(POS))
