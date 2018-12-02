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
import datetime
import argparse, tqdm
import h5py, tarfile
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler


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


# file system watchdog
class watchdog(FileSystemEventHandler):
    def __init__(self):
        super().__init__()

    def on_any_event(self, event):
        if event.is_directory:
            event_dir = event.src_path
        else:
            event_dir = os.path.dirname(event.src_path)
        event_dir = os.path.abspath(event_dir)

    def on_created(self, event):
        currentTime = time.time()
        print(event.src_path)
        if event.is_directory == True:
            inProgress[event.src_path] = currentTime
        else:
            inProgress[os.path.dirname(event.src_path)] = currentTime
        for dirName in list(inProgress.keys()):
            if currentTime - inProgress[dirName] > args.t:
                toProcess.put(dirName)
                del inProgress[dirName]


# file packager
class archiver():
    def __init__(self):
        pass

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
    args = parser.parse_args()
    # start logging
    logger.init(file=args.log)
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



    # check input
    input_dirs = [f for f in args.input if os.path.isdir(f)]
    if len(input_dirs) > 0:
        pass
