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
import os, unittest, yaml


def __is_exe__(fpath):
    return os.path.isfile(fpath) and os.access(fpath, os.X_OK)
    
    
# Test cases
class test_unit_binaries(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', "env.yaml"), 'r') as fp:
            self.nanopype_env = yaml.load(fp)
            
    # Test if basecaller is installed
    def test_callables(self):
        for key, ex in self.nanopype_env['bin'].items():
            print("Testing " + str(key))
            # from https://stackoverflow.com/questions/377017/test-if-executable-exists-in-python
            fpath, fname = os.path.split(ex)
            if fpath:
                if __is_exe__(ex):
                    print(" ".join(["Found", key, "in", fpath]))
                else:
                    raise EnvironmentError(key + ": " + ex + " is not executable")
            else:
                exe_file_valid = None
                for path in os.environ["PATH"].split(os.pathsep):
                    exe_file = os.path.join(path, ex)
                    if os.path.isfile(exe_file) and __is_exe__(exe_file):
                        exe_file_valid = exe_file
                if exe_file_valid:
                    print(" ".join(["Found", key, "in", exe_file_valid]))
                else:
                    raise EnvironmentError(key + ": " + ex + " is not executable or found in PATH")
                
                
# main function
if __name__ == '__main__':
    unittest.main()