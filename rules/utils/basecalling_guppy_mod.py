# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : extract and process base modifications called by guppy
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
import re
import h5py
import numpy as np
#from tqdm import tqdm
from signal import signal, SIGPIPE, SIG_DFL




# read reference genome in fasta format
class ref_genome(dict):
    def __init__(self, ref_file, *args, lazy_load=True, **kwargs):
        super(ref_genome, self).__init__(*args, **kwargs)
        self.ref_file = ref_file
        self.loaded = False
        if not lazy_load:
            self.__load__()

    def __load__(self):
        if not os.path.isfile(self.ref_file):
            raise FileNotFoundError(self.ref_file)
        with open(self.ref_file, 'r') as fp:
            self.update({name[1:]: re.sub(r'\n', '', sequence).upper()
                for ds in re.split(r'\n(?=>.*?\n)', fp.read())
                    for name, sequence in [ds.split('\n', 1)]})
        self.loaded = True

    def __getitem__(self, key):
        if not self.loaded:
            self.__load__()
        return super(ref_genome, self).__getitem__(key)

    def __contains__(self, item):
        if not self.loaded:
            self.__load__()
        return super(ref_genome, self).__contains__(item)




class sam_record():
    def __init__(self, sam_line):
        self.sam_line = sam_line
        fields = sam_line.strip().split('\t')
        QNAME, FLAG, RNAME, POS, _, CIGAR, _, _, _, SEQ = fields[:10]
        opt_fields = [tuple(x.split(':')) for x in fields[11:]]
        self.tags = {f[0]:f[1:] for f in opt_fields}
        self._cigar = CIGAR
        self._cigar_ops = self.__decodeCigar__()
        read_clip_ops = 2 if len(self._cigar_ops) > 3 else 1
        read_clip_begin = sum([x[0] for x in self._cigar_ops[:read_clip_ops] if x[1] in 'S'])
        read_clip_end = sum([x[0] for x in self._cigar_ops[-read_clip_ops:] if x[1] in 'S'])
        self._pos = int(POS) if POS.isnumeric() else 0
        self._rname = RNAME
        self._qname = QNAME
        self._flag = int(FLAG) if FLAG.isnumeric() else 0x4
        self._seq = SEQ[read_clip_begin : -read_clip_end] if read_clip_end else SEQ[read_clip_begin:]

    # decode cigar into list of edits
    def __decodeCigar__(self):
        ops = [(int(op[:-1]), op[-1]) for op in re.findall('(\d*\D)',self._cigar)]
        return ops

    # return length of recognized operations in decoded cigar
    def __opsLength__(self, recOps):
        n = [op[0] for op in self._cigar_ops if op[1] in recOps]
        return sum(n)

    # bool mask of cigar operations
    def __cigar_ops_mask__(self, include='M=X', exclude='DN'):
        flatten = lambda l: [item for sublist in l for item in sublist]
        return np.array(flatten([[True]*l if op in include
                                                else [False]*l if op in exclude
                                                else [] for l, op in self._cigar_ops]))

    # decode MD tag
    def __decode_md__(self):
        flatten = lambda l: [item for sublist in l for item in sublist]
        ops = [m[0] for m in re.findall(r'(([0-9]+)|([A-Z]|\^[A-Z]+))', self.tags["MD"][1])]
        if not len(ops):
            print('[ERROR] Failed to parse MD tag: {}'.format(md), file=sys.stderr)
        ref_mask = np.array(flatten([[True] * int(x) if x.isdigit() else [False] * len(x.strip('^')) for x in ops]))
        seq_mask = np.array(flatten([[True] * int(x) if x.isdigit() else [False] if not '^' in x else [] for x in ops]))
        ref_seq = np.fromstring(''.join(['-' * int(x) if x.isdigit() else x.strip('^') for x in ops]), dtype=np.uint8)
        seq_masked = np.fromstring(self._seq, dtype=np.uint8)[self.__cigar_ops_mask__(include='M=X', exclude='I')]
        ref_seq[ref_mask] = seq_masked[seq_mask]
        return ref_seq.tostring().decode('utf-8')

    def is_reverse(self):
        return self._flag & 0x16

    def get_strand(self):
        return '+' if not 0x16 & self._flag else '-'

    def get_refernce_span(self, ref={}):
        if "MD" in self.tags:
            return self.__decode_md__()
        elif self._rname in ref:
            ref_span = self.__opsLength__("MDN=X")
            return ref[self._rname][self._pos - 1:self._pos -1 + ref_span]
        else:
            raise Exception(self._rname)

    def expand_sequence(self, seq=None):
        seq_ops = "M=XDN" if seq else "M=XI"
        gap_ops = "I" if seq else "DN"
        seq_iter = iter(seq) if seq else iter(self._seq)
        seq_exp = ''.join([''.join([next(seq_iter) for _ in range(l)]) if op in seq_ops else '-'*l if op in gap_ops else '' for l, op in self._cigar_ops])
        return seq_exp

    def expand_array(self, data):
        if self.is_reverse():
            data = data[::-1]
        data_mask = self.__cigar_ops_mask__(include='M=X', exclude="SI")
        ref_mask = self.__cigar_ops_mask__(include='M=X', exclude="DN")
        exp_mask = self.__cigar_ops_mask__(include='M=X', exclude='DI')
        exp_len = self.__opsLength__("MIDN=X")
        ref_span = self.__opsLength__("MDN=X")
        data_expanded = np.zeros((exp_len,), dtype=data.dtype)
        pos_expanded = np.zeros((exp_len,), dtype=np.int64)
        ref_pos = np.arange(self._pos, self._pos + ref_span) - 1
        data_expanded[exp_mask] = data[data_mask]
        pos_expanded[exp_mask] = ref_pos[ref_mask]
        return pos_expanded, data_expanded




# flappie basecaller base modification detection
class methylation_guppy():
    def __init__(self):
        parser = argparse.ArgumentParser(
        description='Nanopore base modification caller',
        usage='''methylation_guppy.py <command> [<args>]
Available guppy commands are:
   extract    Get base probabilities from fast5 files basecalled with 5mC model
   align      Call methylation from probability table and alignment
''')
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(sys.argv[1:2])
        if not hasattr(self, args.command):
            print('Unrecognized command', file=sys.stderr)
            parser.print_help(file=sys.stderr)
            exit(1)
        getattr(self, args.command)(sys.argv[2:])

    def extract(self, argv):
        parser = argparse.ArgumentParser(description="Get base probabilities from fast5 files basecalled with 5mC model")
        parser.add_argument("fast5", nargs='+', help="Path to fast5 with probabilities")
        parser.add_argument("hdf5", help="Path to hdf5 output for probability table")
        args = parser.parse_args(argv)
        with h5py.File(args.hdf5, 'w') as fp_out:
            for fast5 in args.fast5:
                with h5py.File(fast5, 'r') as fp_in:
                    for read_group in fp_in.keys():
                        try:
                            ds = fp_in[read_group + '/Analyses/Basecall_1D_000/BaseCalled_template/ModBaseProbs']
                            assert ds.attrs['table_version'] == b'flipflop_modified_base_probs_v0.1'
                            data = np.core.records.fromarrays(ds[...].transpose())
                            base_mods = iter(ds.attrs['modified_base_long_names'].decode('utf-8').split())
                            base_alphabet = iter(ds.attrs['output_alphabet'].decode('utf-8'))
                            header = [base if base in 'ACGT' else next(base_mods) for base in base_alphabet]
                            dtype = np.dtype([(name, np.uint8) for name in header])
                            fp_out.create_dataset(read_group + '/ModBaseProbs', data=data.astype(dtype), compression='lzf')
                        except Exception as e:
                            print("No mod table for {group} ({msg})".format(group=read_group, msg=str(e)), file=sys.stderr)
                            continue
            fp_out.flush()

    def align(self, argv):
        parser = argparse.ArgumentParser(description="Call methylation from probability table and alignment.")
        parser.add_argument("hdf5", help="Path to hdf5 with probability table.")
        parser.add_argument("--reference", help="Reference in fasta format if MD tag not present in alignment.")
        parser.add_argument("--mod", choices=['5mC', '6mA'], default='5mC', help="Modification to report from probability table")
        parser.add_argument("--context", default='CG', help="Context in reference sequence for modification.")
        args = parser.parse_args(argv)
        # init ref genome, lazy load on first access
        ref = ref_genome(args.reference, lazy_load=True)
        # open probability table
        with h5py.File(args.hdf5, 'r') as fp:
            for line in sys.stdin:
                sam = sam_record(line)
                if not 'read_' + sam._qname in fp:
                    print("[WARNING] Read {} not found in probability table {}".format(sam._qname, args.hdf5), file=sys.stderr)
                    continue
                prob_table = fp['read_' + sam._qname + '/ModBaseProbs'][...][args.mod]
                read_expanded = sam.expand_sequence()
                ref_expanded = sam.expand_sequence(sam.get_refernce_span(ref))
                prob_pos, prob_mapped = sam.expand_array(prob_table)
                for ref_match in re.finditer(args.context, ref_expanded):
                    begin = ref_match.start()
                    end = ref_match.end()
                    ref_begin = prob_pos[begin:end][0]
                    ref_end = prob_pos[begin:end][-1] + 1
                    if re.fullmatch(args.context, read_expanded[begin:end]):
                        prob = prob_mapped[begin] - 127
                        value = '1' if prob >=0 else '0'
                        print('\t'.join([sam._rname, str(ref_begin), str(ref_end), sam._qname, value, sam.get_strand(), str(prob)]))








if __name__ == "__main__":
    signal(SIGPIPE,SIG_DFL)
    methylation_guppy()
