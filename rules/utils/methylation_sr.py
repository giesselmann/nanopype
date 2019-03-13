# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : single read methylation tracks for IGV or GViz
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
import gzip
import argparse
import numpy as np
import timeit
from collections import defaultdict
from signal import signal, SIGPIPE, SIG_DFL




# index for reference genome
class fasta_index(object):
    def __init__(self, fasta, cache=True):
        self.filename = fasta
        self.cache = cache
        self.cache_name = ''
        self.cache_seq = ''
        self.records = {}
        self.record_names = []
        chunkSize = 1024*1024*100
        size = os.path.getsize(self.filename)
        with open(self.filename, 'rb') as fp:
            chunk = fp.read(chunkSize)
            offset = 0
            idx = []
            while chunk != b'':
                idx.extend([m.start()+offset for m in re.finditer(b'>', chunk)])
                offset += chunkSize
                chunk = fp.read(chunkSize)
            idx.append(size)
            for i, o in enumerate(idx[:-1]):
                fp.seek(o)
                title = fp.readline().strip()
                name = title[1:].decode('utf-8')
                self.records[name] = (o, idx[i+1] - o)
                self.record_names.append(name)
                
    def get_record_names(self):
        return self.record_names

    def get_record(self, name):
        if name == self.cache_name:
            return self.cache_seq
        elif name in self.records.keys():
            with open(self.filename, 'r') as fp:
                offset, length = self.records[name]
                fp.seek(offset)
                title = fp.readline()
                fp.seek(offset + len(title))
                seq = fp.read(length - len(title))
                seq = seq.replace('\n', '').upper()
                if self.cache:
                    self.cache_name = name
                    self.cache_seq = seq
                return seq




# parse single read methylation table (abstract base)
class tsv_parser():
    def __init__(self):
        pass
        
    def get_record(self, ID, chr, begin, end, strand):
        raise NotImplementedError()




# parse single read table from nanopolish
class tsv_parser_nanopolish(tsv_parser):
    def __init__(self, tsv_file, log_p_threshold=2.5):
        self.log_p_threshold = log_p_threshold
        f_open = gzip.GzipFile if os.path.splitext(tsv_file)[1] == '.gz' else open
        self.records = defaultdict(list)
        with f_open(tsv_file, 'rb') as fp:
            for line in fp:
                chr, begin, end, ID, log_p_ratio, strand, log_p_5mC, log_p_C = line.decode('utf-8').strip().split('\t')
                ratio = float(log_p_ratio)
                if abs(ratio) >= log_p_threshold:
                    self.records[ID].append((chr, int(begin), int(end), strand, '1' if ratio >= log_p_threshold else '0'))

    def get_record(self, ID, chr, begin, end, strand):
        return [x for x in self.records[ID] if x[0] == chr and x[1] >= begin and x[2] <= end and x[3] == strand]




# parse single read table from flappie
class tsv_parser_flappie(tsv_parser):
    def __init__(self, tsv_file, qval_threshold=3.0):
        self.qval_threshold =qval_threshold
        f_open = gzip.GzipFile if os.path.splitext(tsv_file)[1] == '.gz' else open
        self.records = defaultdict(list)
        with f_open(tsv_file, 'rb') as fp:
            for line in fp:
                chr, begin, end, ID, value, strand, qvalue = line.decode('utf-8').strip().split('\t')
                if float(qvalue) >= qval_threshold:
                    self.records[ID].append((chr, int(begin), int(end), strand, value))

    def get_record(self, ID, chr, begin, end, strand):
        return [x for x in self.records[ID] if x[0] == chr and x[1] >= begin and x[2] <= end and x[3] == strand]




# scramble original sequence on modified sites to get IGV/GViz color coding
class seq_scramble():
    def __init__(self, ref_index, mod_records, mode='IGV', polish=False):
        self.ref_index = ref_index
        self.ref_names = set(ref_index.get_record_names())
        self.mod_records = mod_records
        self.mode = mode
        self.polish = polish
        self.scrambles = {'IGV':
                            {'+':{'11':'CG', '00':'TG', '--':'AG'}, 
                             '-':{'11':'CG', '00':'CA', '--':'AG'}}, 
                          'GViz':
                            {'+':{'11':'AG', '00':'TG', '--':'CG'}, 
                             '-':{'11':'AG', '00':'TG', '--':'CG'}}}
        self.ref_regex = re.compile('CG')
        
    def __groupby__(self, a):
        # source:
        # https://stackoverflow.com/questions/4651683/numpy-grouping-using-itertools-groupby-performance
        diff = np.concatenate(([1], np.diff(a)))
        idx = np.concatenate((np.where(diff)[0], [len(a)]))
        index = np.empty(len(idx)-1,dtype='u4,u4,u4')
        index['f0'] = a[idx[:-1]]
        index['f1'] = np.diff(idx)
        index['f2'] = idx[:-1]
        return index

    # decode cigar into list of edits
    def __decodeCigar__(self, cigar):
        ops = [(int(op[:-1]), op[-1]) for op in re.findall('(\d*\D)',cigar)]
        return ops

    # return length of recognized operations in decoded cigar
    def __opsLength__(self, ops, recOps='MIS=X'):
        n = [op[0] for op in ops if op[1] in recOps]
        return sum(n)
        
    # bool mask of cigar operations
    def __cigar_ops_mask__(self, cigar, include='M=X', exclude='DN'):
        flatten = lambda l: [item for sublist in l for item in sublist]
        dec_cigar = self.__decodeCigar__(cigar)
        return np.array(flatten([[True]*l if op in include 
                                                else [False]*l if op in exclude 
                                                else [] for l, op in dec_cigar]))

    # decode MD tag
    def __decode_md__(self, seq, cigar, md):
        flatten = lambda l: [item for sublist in l for item in sublist]
        ops = [m[0] for m in re.findall(r'(([0-9]+)|([A-Z]|\^[A-Z]+))', md)]
        if not len(ops):
            print(md, file=sys.stderr)
        ref_mask = np.array(flatten([[True] * int(x) if x.isdigit() else [False] * len(x.strip('^')) for x in ops]))
        seq_mask = np.array(flatten([[True] * int(x) if x.isdigit() else [False] if not '^' in x else [] for x in ops]))
        ref_seq = np.fromstring(''.join(['-' * int(x) if x.isdigit() else x.strip('^') for x in ops]), dtype=np.uint8)
        seq_masked = np.fromstring(seq, dtype=np.uint8)[self.__cigar_ops_mask__(cigar, include='M=X', exclude='SI')]
        ref_seq[ref_mask] = seq_masked[seq_mask]
        return ref_seq.tostring().decode('utf-8')
        
    # encode MD tag
    def __encode_md__(self, ref_slice, seq, cigar):
        ref_mask = self.__cigar_ops_mask__(cigar, include='M=X', exclude='DN')
        seq_masked = np.fromstring(seq, dtype=np.uint8)[self.__cigar_ops_mask__(cigar, include='M=X', exclude='SI')]
        seq_states = np.zeros(len(ref_slice), dtype=np.uint8)
        seq_states[ref_mask] = np.where(np.fromstring(ref_slice, dtype=np.uint8)[ref_mask] == seq_masked, 0, 1)
        seq_states[~ref_mask] = 2 # deletion ^ACTG
        md = ''
        seq_state_groups = self.__groupby__(seq_states)
        for i, (state, state_len, state_offset) in enumerate(seq_state_groups):
            if state == 0:      # exact match
                md += str(state_len)
            elif state == 1:    # mismatch
                if state_len == 1:
                    md += ref_slice[state_offset]
                else:
                    md += '0'.join(list(ref_slice[state_offset:state_offset+state_len]))
            elif state == 2:    # deletion
                md += '^' + ref_slice[state_offset : state_offset + state_len]
            if state != 0 and i < len(seq_state_groups) and seq_state_groups[i+1][0] != 0:
                md += '0'
        return md
        
    # scramble seq content on CG sites and fix other mismatches
    def scramble(self, ID, flags, chr, pos, cigar, seq, md=''):
        if not chr in self.ref_names:
            raise KeyError('{rname} not found in {ref}'.format(rname=chr, ref=self.ref_index.filename))
        strand = '-' if flags & 0x16 else '+'
        # parse cigar
        ref_len = self.__opsLength__(self.__decodeCigar__(cigar), recOps='MDN=X')
        ref_begin = pos - 1
        ref_end = pos + ref_len - 1
        if md:
            ref_slice = self.__decode_md__(seq, cigar, md)
        else:
            ref_slice = self.ref_index.get_record(chr)[ref_begin : ref_end]
        # map seq to ref
        flatten = lambda l: [item for sublist in l for item in sublist]
        read_mask = self.__cigar_ops_mask__(cigar, include='M=X', exclude='SI')
        ref_mask = self.__cigar_ops_mask__(cigar, include='M=X', exclude='D')
        read_full = np.fromstring(seq.upper(), dtype=np.uint8)
        read_mapped = np.zeros(len(ref_slice), dtype=np.uint8)
        if not self.polish:
            read_mapped[ref_mask] = read_full[read_mask]
        else:
            read_mapped[ref_mask] = np.fromstring(ref_slice, dtype=np.uint8)[ref_mask]
        # parse methylation marks
        sr_calls = self.mod_records.get_record(ID, chr, ref_begin, ref_end, strand)
        read_mapped_mod = np.fromstring('-' * len(ref_slice), dtype=np.uint8)
        for _, begin, end, _, value in sr_calls:
            read_mapped_mod[begin-ref_begin : end-ref_end if end!=ref_end else len(read_mapped_mod)] = np.fromstring(value * (end - begin), dtype=np.uint8)
        read_mapped_mod = read_mapped_mod.tostring().decode('utf-8')
        # find CGs in reference slice and scramble read according to methylation status
        for ref_match in self.ref_regex.finditer(ref_slice):
            ref_match_begin = ref_match.start()
            ref_match_end = ref_match.end()
            mod_seq = read_mapped_mod[ref_match_begin:ref_match_end]
            if mod_seq == '--' or mod_seq == '11' or mod_seq == '00':
                scramble = self.scrambles[self.mode][strand][mod_seq]
                read_mapped[ref_match_begin:ref_match_end] = np.fromstring(scramble, dtype=np.uint8)
        read_full[read_mask] = read_mapped[ref_mask]
        seq = read_full.tostring().decode('utf-8')
        md = self.__encode_md__(ref_slice, seq, cigar)
        return seq, md




# main
if __name__ == '__main__':
    signal(SIGPIPE,SIG_DFL)
    # cmd line
    parser = argparse.ArgumentParser(description="Single read bisulfite imitation")
    parser.add_argument("ref", help="Reference sequence")
    parser.add_argument("tsv", help="Methylation level tsv file")
    parser.add_argument("--threshold", type=float, default="2.5", help="Q-value threshold")
    parser.add_argument("--method", default="nanopolish", help="Methylation caller used")
    parser.add_argument("--mode", default="IGV", help="Output mode, either IGV or GViz")
    parser.add_argument("--polish", action='store_true', help="Replace matches in sequence with reference")
    args = parser.parse_args()
    # load reference and methylation calls
    ref_idx = fasta_index(args.ref)
    mod_records = tsv_parser_nanopolish(args.tsv, args.threshold) if args.method == 'nanopolish' else tsv_parser_flappie(args.tsv, args.threshold) if args.method == 'flappie' else tsv_parser()
    scrambler = seq_scramble(ref_idx, mod_records, mode=args.mode, polish=args.polish)
    # parse SAM records from stdin and modify seq field
    for line in sys.stdin:
        if line.startswith('@'):
            print(line, end='')
        else:
            fields = line.strip().split('\t')
            opt_fields = [tuple(x.split(':')) for x in fields[11:]]
            opt_md = [f for f in opt_fields if f[0] == 'MD']
            seq, md = scrambler.scramble(fields[0], int(fields[1]), fields[2], int(fields[3]), fields[5], fields[9], md=opt_md[0][2] if opt_md else '')
            fields[9] = seq
            if opt_md:
                fields[11 + opt_fields.index(opt_md[0])] = ':'.join(['MD', 'Z', md])
            else:
                fields.append(':'.join(['MD', 'Z', md]))
            print('\t'.join([str(field) for field in fields]))
