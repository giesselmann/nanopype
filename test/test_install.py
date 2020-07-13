# \TEST\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : test nanopype installation
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
import os, unittest, yaml
from test_base import test_case_base



def __is_exe__(fpath):
    return os.path.isfile(fpath) and os.access(fpath, os.X_OK)




# generic test case locating binaries and testing if executable
class test_case_binary(test_case_base):
    def __init__(self, binary_path='', methodName='none'):
        self.binary_path = binary_path
        # add dynamic named test case
        def fn(self):
           fpath, fname = os.path.split(self.binary_path)
           if fpath:
               if __is_exe__(self.binary_path):
                   return
               else:
                   self.fail('{} is not executable'.format(self.binary_path))
           else:
               exe_file_valid = None
               for path in os.environ["PATH"].split(os.pathsep):
                   exe_file = os.path.join(path, self.binary_path)
                   if os.path.isfile(exe_file) and __is_exe__(exe_file):
                       exe_file_valid = exe_file
               if exe_file_valid:
                   return
               else:
                   self.fail('{} is not executable or found in PATH'.format(self.binary_path))
        super(test_case_binary, self).__init__(fn, methodName)

    def setUp(self):
        pass




# main function
if __name__ == '__main__':
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', "env.yaml"), 'r') as fp:
        nanopype_env = yaml.safe_load(fp)
    suite = unittest.TestSuite()
    for key, ex in nanopype_env['bin'].items():
        suite.addTest(test_case_binary(ex, 'test_binary_{}'.format(key)))
    runner = unittest.TextTestRunner()
    runner.run(suite)
