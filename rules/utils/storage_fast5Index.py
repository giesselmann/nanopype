# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : fast5 raw data index
#
#  DESCRIPTION   : indexing and extraction of single reads
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
import os, sys, argparse
import subprocess, tempfile
import tarfile
import h5py


class fast5_index():
    def __init__(self):
        parser = argparse.ArgumentParser(
        description='Nanopore raw fast5 index',
        usage='''storage_fast5Index.py <command> [<args>]
Available commands are:
   index        Index batch(es) of bulk-fast5 or tar archived single fast5
   extract      Extract single reads from indexed sequencing run
''')
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(sys.argv[1:2])
        if not hasattr(self, args.command):
            print('Unrecognized command', file=sys.stderr)
            parser.print_help(file=sys.stderr)
            exit(1)
        getattr(self, args.command)(sys.argv[2:])

    def __is_multi_read__(self, f5_file):
        with h5py.File(f5_file, 'r') as f5:
            if "/Raw" in f5:
                return False
            else:
                return True

    def __get_ID_single__(self, f5_file):
        with h5py.File(f5_file, 'r') as f5:
            s = f5["/Raw/"].visit(lambda name: name if 'Signal' in name else None)
            return str(f5["/Raw/" + s.rpartition('/')[0]].attrs['read_id'], 'utf-8')

    def __get_ID_multi__(self, f5_file):
        with h5py.File(f5_file, 'r') as f5:
            reads = []
            for group in f5:
                s = f5[group + "/Raw/"].visit(lambda name: name if 'Signal' in name else None)
                ID = (str(f5[group + "/Raw/" + s.rpartition('/')[0]].attrs['read_id'], 'utf-8'))
                reads.append((group, ID))
        return reads

    def index(self, argv):
        parser = argparse.ArgumentParser(description="Flappie methylation reference alignment")
        parser.add_argument("input", help="Input batch or directory of batches")
        parser.add_argument("--recursive", action='store_true', help="Recursively scan input")
        parser.add_argument("--out_prefix", default="", help="Prefix for file paths in output")
        parser.add_argument("--tmp_prefix", default=None, help="Prefix for temporary data")
        args = parser.parse_args(argv)
        input_files = []
        # scan input
        if os.path.isfile(args.input):
            input_files.append(args.input)
        else:
            if args.recursive:
                input_files.extend([os.path.join(dirpath, f) for dirpath, _, files in os.walk(args.input) for f in files if f.endswith('.fast5') or f.endswith('.tar')])
            else:
                input_files.extend(glob.glob(os.path.join(args.input, '*.fast5')))
                input_files.extend(glob.glob(os.path.join(args.input, '*.tar')))
        # index all provided files
        for input_file in input_files:
            # extract reads from packed tar archive and retrieve read IDs
            input_relative = os.path.normpath(os.path.join(args.out_prefix,
                             os.path.dirname(os.path.relpath(input_file, start=args.input)),
                             os.path.basename(input_file)))
            if input_file.endswith('.tar'):
                with tempfile.TemporaryDirectory(prefix=args.tmp_prefix) as tmpdirname, tarfile.open(input_file) as fp_tar:
                    fp_tar.extractall(path=tmpdirname)
                    f5files = [os.path.join(dirpath, f) for dirpath, _, files in os.walk(tmpdirname) for f in files if f.endswith('.fast5')]
                    for f5file in f5files:
                        try:
                            ID = self.__get_ID_single__(f5file)
                            print("\t".join([os.path.normpath(os.path.join(input_relative,
                                             os.path.relpath(f5file, start=tmpdirname))), ID]))
                        except:
                            print("Error opening {f5}, skip file for indexing".format(f5=f5file))
            else:
                if self.__is_multi_read__(input_file):
                    reads = self.__get_ID_multi__(input_file)
                    print("\n".join(['\t'.join((os.path.join(f,group), ID)) for f, (group, ID) in zip([input_relative] * len(reads), reads)]))


    def extract(self, argv):
        pass

if __name__ == "__main__":
    fast5_index()
