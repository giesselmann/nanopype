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
import os, sys, glob, re, enum
import time, datetime
import argparse, tqdm
import h5py, tarfile
import threading
from collections import deque
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler




# logging
class logger():
    logs = [sys.stderr]
    class log_type(enum.Enum):
        Error = "[ERROR]"
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
            print_message = ' '.join([datetime.datetime.now().strftime("%d.%M.%Y %H:%M:%S"), str(type.value), message])
            for log in logger.logs:
                if isinstance(log, str):
                    with open(log, 'a') as fp:
                        print(print_message, file = fp)
                else:
                    print(print_message, file=log)




# thread safe file queue
class delay_queue(object):
    def __init__(self):
        self.__keys = {}
        self.__values = deque()
        self.__lock = threading.Lock()

    def __len__(self):
        with self.__lock:
            return len(self.__values)

    def delay(self, obj):
        with self.__lock:
            if obj in self.__keys:
                self.__values.remove(obj)
            self.__keys[obj] = time.time()
            self.__values.append(obj)

    def delete(self, obj):
        with self.__lock:
            if obj in self.__keys:
                self.__values.remove(obj)
                del self.__keys[obj]

    def get(self, t=0):
        t_now = time.time()
        with self.__lock:
            while len(self.__values) and t_now - self.__values[0][1] > t:
                obj = self.__values.popleft()
                del self.__keys[obj]
                yield obj




# file system watchdog
class watchdog(RegexMatchingEventHandler):
    def __init__(self, base_dir, regexes=['.*'], on_create=None, on_modify=None, on_delete):
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




# package files to batch tar archives
class packager():
    def __init__(self, dest_dir, batch_size):
        pass

    def validate(self, src_dir, dest_dir):
        return src_unique, union_set, dest_unique

    def append(self, src_names):
        pass




# main class
class archiver():
    def __init__(self, src_dirs, regexes=['.*'], recursive=True):
        self.watchdogs = []
        self.observer = []
        self.file_queue = delay_queue()
        self.src_dirs = src_dirs
        self.regexes = regexes

    def start(self):
        logger.log("Start filesystem observer", logger.log_type.Info)
        for dir in iter(self.src_dirs):
            logger.log("Create watchdog for {dir}".format(dir=dir), logger.log_type.Info)
            self.watchdogs.append(watchdog(base_dir=dir, regexes=self.regexes,
                                                on_create=self.file_queue.create,
                                                on_modify=self.file_queue.delay,
                                                on_delete=self.file_queue.delete))
            self.observer.append(Observer())
            self.observer[-1].schedule(self.watchdogs[-1], path=dir, recursive=recursive)
            self.observer[-1].start()

    def stop(self):
        for obs in self.observer:
            obs.stop()
            obs.join()




if __name__ == '__main__':
    # cmd arguments
    parser = argparse.ArgumentParser(description="Nanopype raw data import script",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("output", help="Export directory")
    parser.add_argument("input", nargs="+", help="Base import directory")
    parser.add_argument("-f", "--filter", default="*.fast5", help="File filter regex")
    parser.add_argument("-l", "--log", default=None, help="Log file")
    parser.add_argument("--recursive", action="store_false", help="Recursivly scan import directory")
    parser.add_argument("--watch", action="store_true", help="Watch input for incoming files")
    parser.add_argument("--grace_period", type=int, default=60, help="Time in seconds before treating a file as final")
    args = parser.parse_args()
    # start logging
    logger.init(file=args.log, log_types=[logger.log_type.Error, logger.log_type.Info, logger.log_type.Debug] )
    # check output Directory
    dir_out = os.path.abspath(args.output)
    if os.path.isdir(dir_out):
        if not os.access(dir_out, os.W_OK):
            logger.log("Output directory existent but not writeable", logger.log_type.Error)
    else:
        try:
            os.mkdir(dir_out, mode=0x744)
        except FileExistsError:
            print("Could not create output directory, file {file} already exists".format(file=dir_out), logger.log_type.Error)
            exit(-1)
    logger.log("Writing output to {output}".format(output=dir_out), logger.log_type.Info)
    # check input
    input_dirs = [os.path.abspath(f) for f in args.input if os.path.isdir(f) and os.access(f, os.R_OK)]
    if len(input_dirs) == 0:
        logger.log("No readable input directory specified", logger.log_type.Error)
        exit(-1)
    # create archiver
    arch = archiver(input_dirs)
    try:
        while True:
            pass
    except KeyboardInterrupt:
        pass
