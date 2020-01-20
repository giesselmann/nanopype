# \SCRIPT\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : Import raw fast5 from MinKNOW to nanopype packages
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
# imports
import os, sys, glob, re, enum
import time, datetime
import argparse
import h5py, tarfile
import threading
import queue
from collections import deque
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler
from multiprocessing import Process, Queue




# simple logging
class logger():
    logs = [sys.stdout]
    class log_type(enum.Enum):
        Error = "[ERROR]"
        Warning = "[WARNING]"
        Info = "[INFO]"
        Debug = "[DEBUG]"
    log_types = []

    def init(file=None, log_types=[log_type.Error, log_type.Info]):
        if file:
            if os.path.isfile(file) and os.access(file, os.W_OK) or os.access(os.path.abspath(os.path.dirname(file)), os.W_OK):
                logger.logs.append(file)
        logger.log_types = log_types
        logger.log("Logger created")
        if file and len(logger.logs) == 1:
            logger.log("Log-file {file} is not accessible".format(file=file), logger.log_type.Error)

    def log(message, type=log_type.Info):
        if type in logger.log_types:
            print_message = ' '.join([datetime.datetime.now().strftime("%d.%m.%Y %H:%M:%S"), str(type.value), message])
            for log in logger.logs:
                if isinstance(log, str):
                    with open(log, 'a') as fp:
                        print(print_message, file = fp)
                else:
                    print(print_message, file = log)




# file system watchdog
class fs_event_handler(RegexMatchingEventHandler):
    def __init__(self, base_dir, regexes=['.*'], on_create=None, on_modify=None, on_delete=None):
        super().__init__(regexes=regexes, ignore_directories=True)
        self.on_create = on_create if callable(on_create) else None
        self.on_modify = on_modify if callable(on_modify) else None
        self.on_delete = on_delete if callable(on_delete) else None
        self.base_dir = base_dir

    def on_created(self, event):
        if self.on_create:
            self.on_create(event.src_path)

    def on_moved(self, event):
        if self.on_create and self.base_dir in event.dest_path:
            self.on_create(event.dest_path)

    def on_modified(self, event):
        if self.on_modify:
            self.on_modify(event.src_path)

    def on_deleted(self, event):
        if self.on_delete:
            self.on_delete(event.src_path)




# thread safe file queue
class delay_queue(object):
    def __init__(self):
        self.__keys = {}
        self.__values = deque()
        self.__lock = threading.Lock()

    def __len__(self):
        with self.__lock:
            return len(self.__values)

    def put(self, obj):
        self.delay(obj, update=False)

    def delay(self, obj, update=True):
        with self.__lock:
            if update and obj in self.__keys:
                self.__values.remove(obj)
            self.__keys[obj] = time.time()
            self.__values.append(obj)

    def delete(self, obj):
        with self.__lock:
            if obj in self.__keys:
                self.__values.remove(obj)
                del self.__keys[obj]

    def pop(self, t=0):
        t_now = time.time()
        with self.__lock:
            while len(self.__values) and t_now - self.__keys[obj] > t:
                obj = self.__values.popleft()
                del self.__keys[obj]
                yield obj




# watch filesystem for incoming target files, provide iterator interface on files
class fs_watchdog():
    def __init__(self, src_dirs, regexes):
        self.fs_queue = delay_queue()
        self.src_dirs = list(src_dirs)
        self.regexes = regexes
        self.fs_event_handler = []
        self.fs_observer = []

    def start(self, recursive=True):
        if len(self.fs_observer):
            self.stop()
        for src_dir in self.src_dirs:
            self.fs_event_handler.append(fs_event_handler(src_dir,
                                        self.regexes,
                                        on_create=self.fs_queue.put,
                                        on_modify=self.fs_queue.delay,
                                        on_delete=self.fs_queue.delete))
            self.fs_observer.append(Observer())
            self.fs_observer[-1].schedule(self.fs_event_handler[-1], path=src_dir, recursive=recursive)
            self.fs_observer[-1].start()
            logger.log("Start file system observer on {target}".format(target=src_dir))

    def stop(self):
        logger.log("Stopping file system observer")
        for obs in self.fs_observer:
            obs.stop()
            obs.join()
        logger.log("Stopped file system observer")

    def files(self, t=0):
        return self.fs_queue.pop(t)




# package files to batch tar archives
class packager():
    def __init__(self, src_dirs, dst_dir, recursive=True, ignore_existing=False, regexes=['.*'], batch_size=4000):
        self.src_dirs = src_dirs
        self.dst_dir = dst_dir
        self.recursive = recursive
        self.ignore_existing = ignore_existing
        self.regexes = regexes
        self.batch_size = batch_size
        self.file_queue = Queue()
        self.__packager = None

    def __get_src__(self):
        pattern = '|'.join([r for r in self.regexes])
        existing = []
        for src_dir in self.src_dirs:
            if self.recursive:
                existing.extend([os.path.join(dirpath, f) for dirpath, _, files in os.walk(src_dir) for f in files if re.match(pattern, f)])
            else:
                existing.extend([os.path.join(src_dir, f) for f in os.listdir(src_dir) if re.match(pattern, f)])
        return {os.path.basename(f):f for f in existing}

    def __get_tar__(self):
        tarfiles = [os.path.abspath(os.path.join(self.dst_dir, f)) for f in os.listdir(self.dst_dir) if re.match("[0-9]*.tar", f)]
        return tarfiles

    def __get_dst__(self):
        tarfiles = self.__get_tar__()
        existing = {}
        for tf in tarfiles:
            with tarfile.open(tf) as tar:
                tar_members = tar.getmembers()
                existing.update({tar_member.name:os.path.join(tf, tar_member.name) for tar_member in tar_members})
        return existing

    def __write_tar__(self, fname, batch):
        n = 0
        with tarfile.open(fname, 'w') as fp:
            for f in batch:
                if os.path.isfile(f):
                    fp.add(f, arcname=os.path.basename(f))
                    n += 1
        return n

    def start(self):
        if self.__packager:
            self.__packager.join()
        self.__packager = Process(target=self.__run__, )
        self.__packager.start()

    def stop(self):
        self.file_queue.put(None) # poison pill exit
        self.__packager.join()
        self.__packager = None

    def put(self, src_file):
        self.file_queue.put(os.path.abspath(src_file))

    def __run__(self):
        try:
            # get existing src/dest files
            logger.log("Inspect existing files and archives")
            dst_files = self.__get_dst__()
            src_files = self.__get_src__()
            batch_count = max([0] + [int(os.path.basename(s)[:-4]) + 1 for s in self.__get_tar__()])
            # update on meanwhile queued files from watchdog
            active = True
            try:
                f = self.file_queue.get(block=False)
                while f:
                    src_files[os.path.basename(f)] = f
                    f = self.file_queue.get(block=False)
                if not f:   # poison pill exit on input queue
                    active = False
            except queue.Empty as ex:
                pass
            except KeyboardInterrupt:
                logger.log("Stop inspection on user request")
                return
            # put not yet archived to processing queue
            processing_queue = deque()
            src_keys = set(src_files.keys())
            dst_keys = set(dst_files.keys())
            to_archive = src_keys.difference(dst_keys)
            archived = dst_keys.intersection(src_keys)
            archived_only = dst_keys.difference(src_keys)
            logger.log("{archived} raw files already archived".format(archived=len(archived)))
            logger.log("{to_archive} raw files to be archived".format(to_archive=len(to_archive)))
            if len(archived_only) > 0:
                logger.log("{archived_only} files in archive but not found in source directory".format(archived_only=len(archived_only)), logger.log_type.Warning)
                if not self.ignore_existing:
                    logger.log("Exiting with files in archive not found in source directory. Re-run with --ignore_existing to archive anyway")
                    return
            processing_queue.extend(sorted([src_files[f] for f in to_archive]))
            # enter main archive loop
            while active:
                # get file names from queue
                try:
                    try:
                        f = self.file_queue.get(block=False)
                        while f:
                            processing_queue.append(f)
                            f = self.file_queue.get(block=False)
                        if f is None:   # poison pill exit
                            active = False
                    except queue.Empty as ex:
                        pass
                    # archive files in batches
                    while len(processing_queue) >= self.batch_size:
                        batch = [processing_queue.popleft() for i in range(self.batch_size)]
                        batch_name = os.path.join(self.dst_dir, str(batch_count) + '.tar')
                        try:
                            n = self.__write_tar__(batch_name, batch)
                        except KeyboardInterrupt:
                            logger.log("Archiving of {archive} interrupted. The file is likely damaged".format(archive=batch_name))
                            raise
                        batch_count += 1
                        logger.log("Archived {count} reads in {archive}".format(count=n, archive=batch_name))
                except KeyboardInterrupt:
                    # leave controlled shutdown to master process
                    break
            # archive remaining reads
            while len(processing_queue) > 0:
                batch =  [processing_queue.popleft() for i in range(min(len(processing_queue), self.batch_size))]
                batch_name = os.path.join(self.dst_dir, str(batch_count) + '.tar')
                if len(batch) > 0:
                    n = self.__write_tar__(batch_name, batch)
                    logger.log("Archived {count} reads in {archive}".format(count=n, archive=batch_name))
                    batch_count += 1
        except KeyboardInterrupt:
            logger.log("Archive worker shutdown on user request")
            return




if __name__ == '__main__':
    # cmd arguments
    parser = argparse.ArgumentParser(description="Nanopype raw data import script",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("output", help="Export directory")
    parser.add_argument("input", nargs="+", help="Import directories")
    parser.add_argument("-f", "--filter", nargs="+", default=[".*\.fast5"], help="File filter regex")
    parser.add_argument("-b", "--batch_size", type=int, default=4000, help="Number of files to put into one archive")
    parser.add_argument("--recursive", action="store_true", help="Recursivly scan import directory")
    parser.add_argument("--watch", action="store_true", help="Watch input for incoming files")
    parser.add_argument("-l", "--log", default=None, help="Log file")
    parser.add_argument("--grace_period", type=int, default=60, help="Time in seconds before treating a file as final")
    parser.add_argument("--ignore_existing", action="store_true", help="Proceed with files found in archive but not in import location")
    args = parser.parse_args()
    # start logging
    logger.init(file=args.log, log_types=[logger.log_type.Error, logger.log_type.Info, logger.log_type.Debug] )
    # check output Directory
    dir_out = os.path.abspath(args.output)
    if not (dir_out.endswith('reads') or dir_out.endswith('reads' + os.sep)):
        dir_out = os.path.join(dir_out, 'reads')
    if os.path.isdir(dir_out):
        if not os.access(dir_out, os.W_OK):
            logger.log("Output directory existent but not writeable", logger.log_type.Error)
    else:
        try:
            os.makedirs(dir_out, mode=0o744, exist_ok=True)
        except FileExistsError:
            print("Could not create output directory, file {file} already exists".format(file=dir_out), logger.log_type.Error)
            exit(-1)
    logger.log("Writing output to {output}".format(output=dir_out), logger.log_type.Info)
    # check input
    input_dirs = [os.path.abspath(f) for f in args.input if os.path.isdir(f) and os.access(f, os.R_OK)]
    if len(input_dirs) == 0:
        logger.log("No readable input directory specified", logger.log_type.Error)
        exit(-1)
    # create packager
    pkgr = packager(input_dirs, dir_out, recursive=args.recursive, ignore_existing=args.ignore_existing, regexes=args.filter, batch_size=args.batch_size)
    pkgr.start()
    # create fs watchdogs
    if args.watch:
        wtchdg = fs_watchdog(input_dirs, args.filter)
        wtchdg.start()
        logger.log("Started file system observer, press CTRL + C to abort")
        try:
            while True:
                for f in wtchdg.files(t=args.grace_period):
                    pkgr.put(f)
        except KeyboardInterrupt:
            logger.log("Abort by user, trying to shutdown properly")
            wtchdg.stop()
    try:
        pkgr.stop()
    except KeyboardInterrupt:
        pkgr.stop() # packager has received interrupt and will shutdown
    logger.log("Mission accomplished")
