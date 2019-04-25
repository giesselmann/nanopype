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
from ont_fast5_api.fast5_interface import is_multi_read
from ont_fast5_api.fast5_file import Fast5File
from ont_fast5_api.multi_fast5 import MultiFast5File
from ont_fast5_api.conversion_tools import multi_to_single_fast5, single_to_multi_fast5


class fast5_Index():
    def __init__(self, index_file=None, tmp_prefix=None):
        self.index_file = index_file
        self.tmp_prefix = tmp_prefix
        if index_file and not os.path.exists(index_file):
            raise RuntimeError("[Error] Raw fast5 index file {} not found.".format(index_file))
        elif index_file:
            with open(index_file, 'r') as fp:
                self.index_dict = {id:path for path,id in [line.split('\t') for line in fp.read().split('\n') if line]}
        else:
            self.index_dict = None

    def __chunked__(l, n):
        for i in range(0, len(l), n):
            yield l[i:i + n]

    def __get_ID_single__(f5_file):
        with h5py.File(f5_file, 'r') as f5:
            s = f5["/Raw/"].visit(lambda name: name if 'Signal' in name else None)
            return str(f5["/Raw/" + s.rpartition('/')[0]].attrs['read_id'], 'utf-8')

    def __get_ID_multi__(f5_file):
        with h5py.File(f5_file, 'r') as f5:
            reads = []
            for group in f5:
                s = f5[group + "/Raw/"].visit(lambda name: name if 'Signal' in name else None)
                ID = (str(f5[group + "/Raw/" + s.rpartition('/')[0]].attrs['read_id'], 'utf-8'))
                reads.append((group, ID))
        return reads

    def __copy_reads_to__(self, read_ids, output):
        if not os.path.exists(output):
            os.makedirs(output)
        batch_id_files = [tuple( [id] + re.split('(\.fast5|\.tar)\/', self.index_dict[id]) ) for id in read_ids if id in self.index_dict]
        batch_id_files.sort(key=lambda x : (x[1], x[2]) if len(x) > 2 else x[1])
        for _, id_batch_paths in itertools.groupby(batch_id_files, key=lambda x : (x[1], x[2]) if len(x) > 2 else x[1]):
            fofns = list(id_batch_paths)
            if len(fofns) == 1 and len(fofns[0]) == 2:
                # single read fast5
                id, src_file = fofns[0]
                shutil.copy(os.path.join(os.path.dirname(args.index), src_file), output)
            else:
                _, batch_file, batch_ext, _ = fofns[0]
                tarFiles = set([x[3] for x in fofns])
                # single read fast5 batch in tar archive
                if batch_ext == '.tar':
                    tar_file = os.path.join(os.path.dirname(self.index_file), batch_file + batch_ext)
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
                    f5_file = os.path.join(os.path.dirname(self.index_file), batch_file + batch_ext)
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

    def index(input, recursive=False, output_prefix="", tmp_prefix=None):
        if tmp_prefix and not os.path.exists(tmp_prefix):
            os.makedirs(tmp_prefix)
        input_files = []
        # scan input
        if os.path.isfile(input):
            input_files.append(input)
        else:
            if recursive:
                input_files.extend([os.path.join(dirpath, f) for dirpath, _, files in os.walk(input) for f in files if f.endswith('.fast5') or f.endswith('.tar')])
            else:
                input_files.extend(glob.glob(os.path.join(input, '*.fast5')))
                input_files.extend(glob.glob(os.path.join(input, '*.tar')))
        # index all provided files
        for input_file in input_files:
            input_relative = os.path.normpath(os.path.join(output_prefix,
                             os.path.dirname(os.path.relpath(input_file, start=input)),
                             os.path.basename(input_file)))
            # extract reads from packed tar archive and retrieve read IDs
            if input_file.endswith('.tar'):
                with tempfile.TemporaryDirectory(prefix=tmp_prefix) as tmpdirname, tarfile.open(input_file) as fp_tar:
                    fp_tar.extractall(path=tmpdirname)
                    f5files = [os.path.join(dirpath, f) for dirpath, _, files in os.walk(tmpdirname) for f in files if f.endswith('.fast5')]
                    for f5file in f5files:
                        try:
                            ID = fast5_Index.__get_ID_single__(f5file)
                            print("\t".join([os.path.normpath(os.path.join(input_relative,
                                             os.path.relpath(f5file, start=tmpdirname))), ID]))
                        except:
                            print("[ERROR] Failed to open {f5}, skip file for indexing".format(f5=f5file), file=sys.stderr)
            # bulk and single read fast5
            else:
                if is_multi_read(input_file):
                    reads = fast5_Index.__get_ID_multi__(input_file)
                    for f, (group, ID) in zip([input_relative] * len(reads), reads):
                        yield '\t'.join((os.path.join(f,group), ID))
                else:
                    try:
                        ID = fast5_Index.__get_ID_single__(input_relative)
                    except:
                        print("[ERROR] Failed to open {f5}, skip file for indexing".format(f5=input_file), file=sys.stderr)
                    yield '\t'.join([input_relative, ID])

    def extract(self, input, output, format='single'):
        if not os.path.exists(output):
            os.makedirs(output)
        batch_name, batch_ext = os.path.splitext(input)
        # packed single reads in tar archive
        if batch_ext == '.tar':
            if format in ['single', 'lazy']:
                with tarfile.open(input) as fp_tar:
                    fp_tar.extractall(path=output)
            else:
                with tempfile.TemporaryDirectory(prefix=self.tmp_prefix) as tmpdirname, tarfile.open(input) as fp_tar:
                    fp_tar.extractall(path=tmpdirname)
                    f5files = [os.path.join(dirpath, f) for dirpath, _, files in os.walk(tmpdirname) for f in files if f.endswith('.fast5')]
                    output_bulk_file = os.path.join(output, os.path.basename(batch_name) + '.fast5')
                    single_to_multi_fast5.create_multi_read_file(f5files, output_bulk_file)
        # bulk fast5
        elif batch_ext == '.fast5':
            if format in ['bulk', 'lazy']:
                shutil.copy(input, output)
            else:
                multi_to_single_fast5.convert_multi_to_single(input, output, '')
        # read IDs to be extracted
        elif batch_ext == '.txt':
            # load index and requested IDs
            if not self.index_dict :
                raise RuntimeError("[Error] Extraction of reads from IDs without index file provided.")
            with open(input, 'r') as fp:
                batch_ids = [id.strip() for id in fp.read().split('\n') if id]
            if format in ['single', 'lazy']:
                self.__copy_reads_to__(batch_ids, output)
            else:
                with tempfile.TemporaryDirectory(prefix=self.tmp_prefix) as tmpdirname:
                    self.__copy_reads_to__(batch_ids, tmpdirname)
                    f5files = [os.path.join(dirpath, f) for dirpath, _, files in os.walk(tmpdirname) for f in files if f.endswith('.fast5')]
                    if len(f5files) > 4000:
                        for i, f5_batch in enumerate(fast5_Index.__chunked__(f5files, 4000)):
                            output_bulk_file = os.path.join(output, os.path.basename(batch_name) + '_{i}.fast5'.format(i=i))
                            single_to_multi_fast5.create_multi_read_file(f5_batch, output_bulk_file)
                    else:
                        output_bulk_file = os.path.join(output, os.path.basename(batch_name) + '.fast5')
                        single_to_multi_fast5.create_multi_read_file(f5files, output_bulk_file)
        else:
            raise RuntimeError('[ERROR] Raw fast5 batch extension {} not supported.'.format(batch_ext))

    def raw(self, ID):
        pass


class main():
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

    def index(self, argv):
        parser = argparse.ArgumentParser(description="Fast5 Index")
        parser.add_argument("input", help="Input batch or directory of batches")
        parser.add_argument("--recursive", action='store_true', help="Recursively scan input")
        parser.add_argument("--out_prefix", default="", help="Prefix for file paths in output")
        parser.add_argument("--tmp_prefix", default=None, help="Prefix for temporary data")
        args = parser.parse_args(argv)
        for record in fast5_Index.index(args.input, recursive=args.recursive, output_prefix=args.out_prefix, tmp_prefix=args.tmp_prefix):
            print(record)

    def extract(self, argv):
        parser = argparse.ArgumentParser(description="Fast5 extraction")
        parser.add_argument("batch", help="Input batch")
        parser.add_argument("output", help="Output directory")
        parser.add_argument("--index", default=None, help="Read index")
        parser.add_argument("--output_format", default='single', choices=['single', 'bulk', 'lazy'], help="Output as single, bulk or with minimal conversion overhead")
        parser.add_argument("--tmp_prefix", default=None, help="Prefix for temporary data")
        args = parser.parse_args(argv)
        f5_index = fast5_Index(args.index, tmp_prefix=args.tmp_prefix)
        f5_index.extract(args.batch, args.output, format=args.output_format)




if __name__ == "__main__":
    main()
