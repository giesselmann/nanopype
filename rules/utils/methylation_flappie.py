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
from collections import defaultdict
from signal import signal, SIGPIPE, SIG_DFL


# parse fasta/fastq
def fastxIter(iterable):
    it = iter(iterable)
    line = next(it)
    if hasattr(line, 'decode'):
        line = line.decode('utf-8').strip()
        next_decode = lambda *args: next(*args).decode('utf-8').strip()
    else:
        line = line.strip()
        next_decode = lambda *args: next(*args).strip()
    while True:
        if line is not None and len(line) > 0:
            if line[0] == '@':      # fastq
                name = line
                sequence = next_decode(it)
                comment = next_decode(it)
                quality = next_decode(it)
                yield name, sequence, comment, quality
                line = next_decode(it)
            elif line[0] == '>':      # fasta
                name = line
                sequence = next_decode(it)
                try:
                    line = next_decode(it)
                except StopIteration:
                    yield name, sequence.upper()
                    return
                while line is not None and len(line) > 0 and line[0] != '>' and line[0] != '@':
                    sequence += line
                    try:
                        line = next_decode(it)
                    except StopIteration:
                        yield name, sequence.upper()
                        return
                yield name, sequence.upper()
            else:
                print("error parsing header line {}".format(line), file=sys.stderr)
                sys.exit(-1)
        elif line is None:
            raise StopIteration()
        else:
            print("error parsing line {}".format(line), file=sys.stderr)
            sys.exit(-1)



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




# flappie basecaller base modification detection
class methylation_flappie():
    def __init__(self):
        parser = argparse.ArgumentParser(
        description='Nanopore base modification caller',
        usage='''methylation_flappie.py <command> [<args>]
Available flappie commands are:
   split      Split input fastq with modified base into fastq and annotation
   align      Call methylation from fastq, annotation and alignment
''')
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(sys.argv[1:2])
        if not hasattr(self, args.command):
            print('Unrecognized command', file=sys.stderr)
            parser.print_help(file=sys.stderr)
            exit(1)
        getattr(self, args.command)(sys.argv[2:])
        
    # decode cigar into list of edits
    def __decodeCigar__(self, cigar):
        ops = [(int(op[:-1]), op[-1]) for op in re.findall('(\d*\D)',cigar)]
        return ops

    # return length of recognized operations in decoded cigar
    def __opsLength__(self, ops, recOps='MIS=X'):
        n = [op[0] for op in ops if op[1] in recOps]
        return sum(n)
        
    def __annotate__(self, qname, flag, rname, pos, cigar):
        if rname in self.ref and qname in self.reads and qname in self.annotation:
            # restore original sequence
            read_seq, read_quality = self.reads[qname]
            for begin, end, seq_origin, seq_ref, seq_qual in self.annotation[qname]:
                read_seq = read_seq[:begin] + seq_origin + read_seq[end:]
            # parse cigar
            dec_cigar = self.__decodeCigar__(cigar)
            ref_len = self.__opsLength__(dec_cigar, recOps='MDN=X')
            read_clip_ops = 2 if len(dec_cigar) > 3 else 1
            read_clip_begin = sum([x[0] for x in dec_cigar[:read_clip_ops] if x[1] in 'SH'])
            read_clip_end = sum([x[0] for x in dec_cigar[-read_clip_ops:] if x[1] in 'SH'])
            # matching ref and read slices
            ref_slice = self.ref[rname][pos - 1 : pos - 1 + ref_len]
            if flag & 0x16:
                read_slice = read_seq[read_clip_end : -read_clip_begin] if read_clip_begin else read_seq[read_clip_end:]
                qual_slice = read_quality[read_clip_end : -read_clip_begin] if read_clip_begin else read_quality[read_clip_end:]
                strand = '-'
            else:
                read_slice = read_seq[read_clip_begin : -read_clip_end] if read_clip_end else read_seq[read_clip_begin:]
                qual_slice = read_quality[read_clip_begin : -read_clip_end] if read_clip_end else read_quality[read_clip_begin:]
                strand = '+'
            # expand ref to read
            flatten = lambda l: [item for sublist in l for item in sublist]
            read_mask = np.array(flatten([[True]*l if op in 'M=X' else [False]*l if op in 'I' else [] for l, op in dec_cigar]))
            ref_mask = np.array(flatten([[True]*l if op in 'M=X' else [False]*l if op in 'DN' else [] for l, op in dec_cigar]))
            ref_seq = np.array(['-'] * len(read_mask))
            ref_seq[read_mask] = np.array([c for c in ref_slice])[ref_mask]
            ref_seq = ''.join(ref_seq)
            ref_pos = np.zeros(len(read_mask), dtype=int)
            ref_pos[read_mask] = np.array(range(pos-1, pos-1+len(ref_slice)))[ref_mask]
            # reverse complement ref sequence for complement reads
            complement = lambda s, cmp={'A':'T','T':'A','C':'G','G':'C'}:''.join([cmp[t] if t in cmp else '-' for t in s])
            if flag & 0x16:
                ref_seq = complement(ref_seq)[::-1]
                ref_pos = ref_pos[::-1]
            # search pattern on reference, check value in read
            for ref_match in self.ref_regex.finditer(ref_seq):
                ref_match_temp_begin = ref_pos[min(ref_match.start(), ref_match.end())]
                ref_match_temp_end = ref_pos[max(ref_match.start(), ref_match.end())-1]
                ref_match_seq = ref_seq[ref_match.start():ref_match.end()]
                read_match_seq = read_slice[ref_match.start():ref_match.end()]
                read_match_qual = qual_slice[ref_match.start():ref_match.end()]
                if len(ref_match_seq) != ref_match_temp_end - ref_match_temp_begin + 1:
                    # insertion over CpG
                    continue
                read_match_qual = sum([ord(x) - 33 for x in read_match_qual]) / len(read_match_qual)
                read_mod_match = self.mod_regex.fullmatch(read_match_seq)
                read_base_match = self.ref_regex.fullmatch(read_match_seq)
                if read_mod_match:
                    value = '1'
                elif read_base_match:
                    value = '0'
                if read_mod_match or read_base_match:
                    print('\t'.join([rname, str(ref_match_temp_begin), str(ref_match_temp_end + 1), qname, value, strand, str(read_match_qual)]))

    # split flappie sequence into ACTG-alphabet fastq output and annotation of modified sites in the original sequence
    def split(self, argv):
        parser = argparse.ArgumentParser(description="Flappie fastq output split")
        parser.add_argument("annotation", help="Path to annotation tsv file")
        parser.add_argument("--mod_seq", default="ZG", help="Sequence indicating base modification")
        parser.add_argument("--ref_seq", default="CG", help="Replacement sequence to enable generic alignment")
        args = parser.parse_args(argv)
        assert len(args.mod_seq) == len(args.ref_seq)
        mod_regex = re.compile(args.mod_seq)
        with open(args.annotation, 'w') as fp:
            for name, sequence, comment, quality in fastxIter(sys.stdin):
                ID = name[1:].split()[0]
                def replace_mod(match_obj):
                    print('\t'.join([ID, str(match_obj.start()), str(match_obj.end()), sequence[match_obj.start():match_obj.end()], args.ref_seq, quality[match_obj.start():match_obj.end()]]), file=fp)
                    return args.ref_seq
                sequence_clean = re.sub(mod_regex, replace_mod, sequence)
                assert len(sequence) == len(sequence_clean)
                print("\n".join([name, sequence_clean, comment, quality]))

    # map flappie reported modification sites against reference genome
    def align(self, argv):
        parser = argparse.ArgumentParser(description="Flappie methylation reference alignment")
        parser.add_argument("reference", help="Path to reference genome sequence")
        parser.add_argument("sequences", help="Path to read sequence")
        parser.add_argument("annotation", help="Path to annotation tsv file")
        parser.add_argument("--mod_seq", default="ZG", help="Sequence indicating base modification")
        parser.add_argument("--ref_seq", default="CG", help="Replacement sequence to enable generic alignment")
        parser.add_argument("--q-val", type=int, default=0, help="Threshold for sequence quality to report modification")
        args = parser.parse_args(argv)
        self.ref_regex = re.compile(args.ref_seq)
        self.mod_regex = re.compile(args.mod_seq)
        self.ref = {}
        # load reference genome into memory
        f_open = gzip.GzipFile if os.path.splitext(args.reference)[1] == '.gz' else open
        with f_open(args.reference, 'rb') as fp:
            self.ref = {name[1:].split()[0]:sequence.upper() for name, sequence in fastxIter(fp)}
        # load replaced sequences per read into memory
        self.annotation = defaultdict(list)
        f_open = gzip.GzipFile if os.path.splitext(args.annotation)[1] == '.gz' else open
        with f_open(args.annotation, 'rb') as fp:
            for line in fp:
                line_dec = line.decode('utf-8').strip()
                ID, begin, end, seq_origin, seq_ref, seq_qual = line_dec.split('\t')
                self.annotation[ID].append((int(begin), int(end), seq_origin, seq_ref, seq_qual))
        # load read sequences
        self.reads = {}
        f_open = gzip.GzipFile if os.path.splitext(args.sequences)[1] == '.gz' else open
        with f_open(args.sequences, 'rb') as fp:
            self.reads = {name[1:].split()[0]:(sequence.upper(), quality) for name, sequence, _, quality in fastxIter(fp)}
        # parse alignments in SAM format from STDIN
        for line in sys.stdin:
            fields = line.strip().split('\t')
            QNAME, FLAG, RNAME, POS, _, CIGAR, _, _, _, SEQ = fields[:10]
            self.__annotate__(QNAME, int(FLAG), RNAME, int(POS), CIGAR)




if __name__ == '__main__':
    signal(SIGPIPE,SIG_DFL)
    methylation_flappie()
