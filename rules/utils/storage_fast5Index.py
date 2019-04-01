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
import os, sys, re, argparse
import itertools
import shutil
import tempfile, tarfile
import h5py
from ont_fast5_api.fast5_file import Fast5File
from ont_fast5_api.multi_fast5 import MultiFast5File
from ont_fast5_api.conversion_tools import multi_to_single_fast5, single_to_multi_fast5




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
        parser = argparse.ArgumentParser(description="Fast5 Index")
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
            input_relative = os.path.normpath(os.path.join(args.out_prefix,
                             os.path.dirname(os.path.relpath(input_file, start=args.input)),
                             os.path.basename(input_file)))
            # extract reads from packed tar archive and retrieve read IDs
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
            # bulk and single read fast5
            else:
                if self.__is_multi_read__(input_file):
                    reads = self.__get_ID_multi__(input_file)
                    print("\n".join(['\t'.join((os.path.join(f,group), ID)) for f, (group, ID) in zip([input_relative] * len(reads), reads)]))
                else:
                    print('\t'.join([input_relative, self.__get_ID_single__(input_relative)]))

    def extract(self, argv):
        parser = argparse.ArgumentParser(description="Fast5 extraction")
        parser.add_argument("batch", help="Input batch")
        parser.add_argument("output", help="Output directory")
        parser.add_argument("--index", default='', help="Read index")
        parser.add_argument("--output_format", default='single', choices=['single', 'bulk', 'lazy'], help="Output as single, bulk or with minimal conversion overhead")
        parser.add_argument("--tmp_prefix", default=None, help="Prefix for temporary data")
        args = parser.parse_args(argv)
        if not os.path.exists(args.output):
            os.makedirs(os.path.dirname(output_file))
        batch_name, batch_ext = os.path.splitext(args.batch)
        # packed single reads in tar archive
        if batch_ext == '.tar':
            if args.output_format in ['single', 'lazy']:
                with tarfile.open(args.batch) as fp_tar:
                    fp_tar.extractall(path=args.output)
            else:
                output_bulk = os.path.join(args.output, os.path.basename(batch_name) + '.fast5')
                with tempfile.TemporaryDirectory(prefix=args.tmp_prefix) as tmpdirname, tarfile.open(args.batch) as fp_tar:
                    fp_tar.extractall(path=tmpdirname)
                    f5files = [os.path.join(dirpath, f) for dirpath, _, files in os.walk(tmpdirname) for f in files if f.endswith('.fast5')]
                    single_to_multi_fast5.create_multi_read_file(f5files, output_bulk)
        # bulk fast5
        elif batch_ext == '.fast':
            if args.output_format in ['bulk', 'lazy']:
                shutil.copy(args.batch, args.output)
            else:
                multi_to_single_fast5.convert_multi_to_single(args.batch, args.output, '')
        # read IDs to be extracted
        elif batch_ext == '.txt':
            # load index and requested IDs
            if not os.path.exists(args.index):
                raise RuntimeError("[Error] Raw fast5 index file {} not found.".format(args.index))
            else:
                with open(args.batch, 'r') as fp:
                    batch_ids = [id.strip() for id in fp.read().split('\n') if id]
                with open(args.index, 'r') as fp:
                    run_index = {id:path for path,id in [line.split('\t') for line in fp.read().split('\n') if line]}
            # sort in affected batches
            batch_id_files = [tuple( [id] + re.split('(\.fast5|\.tar)\/', run_index[id]) ) for id in batch_ids if id in run_index]
            batch_id_files.sort(key=lambda x : (x[1], x[2]) if len(x) > 2 else x[1])
            def copy_reads_to(fofns, output):
                if len(fofns) == 1 and len(fofns[0]) == 2:
                    # single read fast5
                    id, src_file = fofns[0]
                    shutil.copy(os.path.join(os.path.dirname(args.index), src_file), output)
                else:
                    _, batch_file, batch_ext, _ = fofns[0]
                    tarFiles = set([x[3] for x in fofns])
                    # single read fast5 batch in tar archive
                    if batch_ext == '.tar':
                        tar_file = os.path.join(os.path.dirname(args.index), batch_file + batch_ext)
                        with tarfile.open(tar_file) as fp_tar:
                            tar_members = fp_tar.getmembers()
                            for tar_member in tar_members:
                                if any(s in tar_member.name for s in tarFiles):
                                    try:
                                        tar_member.name = os.path.basename(tar_member.name)
                                        fp_tar.extract(tar_member, path=output)
                                    except:
                                        RuntimeError('[ERROR] Could not extract {id} from {batch}.'.format(id=tar_member.name, batch=tar_file))
                    elif batch_ext == '.fast5':
                        f5_file = os.path.join(os.path.dirname(args.index), batch_file + batch_ext)
                        with MultiFast5File(f5_file, 'r') as multi_f5:
                            target_ids = set([x[0] for x in fofns])
                            for read_id in multi_f5.get_read_ids():
                                if read_id in target_ids:
                                    try:
                                        read = multi_f5.get_read(read_id)
                                        output_file = os.path.join(output, "{}.fast5".format(read_id))
                                        multi_to_single_fast5.create_single_f5(output_file, read)
                                    except:
                                        RuntimeError('[ERROR] Could not extract {id} from {batch}.'.format(id=read_id, batch=f5_file))
                    else:
                        pass
            for batch_file, id_batch_paths in itertools.groupby(batch_id_files, key=lambda x : (x[1], x[2]) if len(x) > 2 else x[1]):
                if args.output_format in ['single', 'lazy']:
                    copy_reads_to(list(id_batch_paths), args.output)
                else:
                    output_bulk = os.path.join(args.output, os.path.basename(batch_name) + '.fast5')
                    with tempfile.TemporaryDirectory(prefix=args.tmp_prefix) as tmpdirname:
                        copy_reads_to(list(id_batch_paths), tmpdirname)
                        f5files = [os.path.join(dirpath, f) for dirpath, _, files in os.walk(tmpdirname) for f in files if f.endswith('.fast5')]
                        single_to_multi_fast5.create_multi_read_file(f5files, output_bulk)

        else:
            raise RuntimeError('[ERROR] Raw fast5 batch extension {} not supported.'.format(batch_ext))




if __name__ == "__main__":
    fast5_index()
