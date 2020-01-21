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
import h5py
import numpy as np
from signal import signal, SIGPIPE, SIG_DFL




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
        parser.add_argument("fast5", help="Path to fast5 with probabilities")
        parser.add_argument("hdf5", help="Path to hdf5 output for probability table")
        args = parser.parse_args(argv)
        with h5py.File(args.fast5, 'r') as fp_in, h5py.File(args.hdf5, 'w') as fp_out:
            for read_group in fp_in.keys():
                ds = fp_in[read_group + '/Analyses/Basecall_1D_000/BaseCalled_template/ModBaseProbs']
                assert ds.attrs['table_version'] == b'flipflop_modified_base_probs_v0.1'
                data = np.core.records.fromarrays(ds[...].transpose())
                base_mods = iter(ds.attrs['modified_base_long_names'].decode('utf-8').split())
                base_alphabet = iter(ds.attrs['output_alphabet'].decode('utf-8'))
                header = [base if base in 'ACGT' else next(base_mods) for base in base_alphabet]
                dtype = np.dtype([(name, np.uint8) for name in header])
                fp_out.create_dataset(read_group + '/ModBaseProbs', data=data.astype(dtype), compression='lzf')
            fp_out.flush()




if __name__ == "__main__":
    signal(SIGPIPE,SIG_DFL)
    methylation_guppy()
