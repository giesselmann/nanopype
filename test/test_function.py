# \TEST\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : test nanopype modules
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
import os, glob, argparse, yaml
import subprocess
import unittest
import filecmp, shutil, wget
import urllib.request
from test_base import test_case_base




base_url = 'https://owww.molgen.mpg.de/~nanopype/unit/{}'




def init_test_dir(repo_dir, test_dir='.'):
    if not os.path.exists(test_dir):
        os.makedirs(test_dir)
    os.chdir(test_dir)
    # get list of filenames
    fofn_url = base_url.format('index.fofn')
    files = [file for file in urllib.request.urlopen(fofn_url).read().decode('utf-8').split('\n') if file]
    # download files from
    for file in files:
        file_dir = os.path.dirname(file)
        os.makedirs(file_dir, exist_ok=True)
        if os.path.isfile(file):
            os.remove(file)
        wget.download(base_url.format(file), file, bar=None)
    # copy nanopype.yaml from repo
    shutil.copyfile(os.path.join(repo_dir, 'nanopype.yaml'),
                    './nanopype.yaml')
    # init test_dir as git repo to track changes
    if not os.path.isdir('.git'):
        subprocess.run('git init', check=True, shell=True, stdout=subprocess.PIPE)
    with open('.gitignore', 'w') as fp:
        print(".snakemake", file=fp)
        print("**/__pycache__", file=fp)
        print("log", file=fp)
    subprocess.run('git add .', check=True, shell=True, stdout=subprocess.PIPE)
    subprocess.run('git commit -m "init"', check=False, shell=True, stdout=subprocess.PIPE)
    return os.getcwd()




def reset_test_dir(test_dir='.'):
    subprocess.run('git reset --hard', check=True, shell=True, stdout=subprocess.PIPE)
    subprocess.run('git clean -f -d', check=True, shell=True, stdout=subprocess.PIPE)




class test_case_src(test_case_base):
    def __init__(self, snakefile, test_file, test_dir='.', methodName='none'):
        self.test_dir = test_dir
        base_cmd = 'snakemake -q -j 4 --snakefile {snakefile} --directory {test_dir} '.format(
            snakefile=snakefile, test_dir=test_dir)
        def fn(self):
            # move expected output file if present
            exp = False
            if os.path.isfile(test_file):
                shutil.move(test_file, test_file + '.expected_output')
                exp = True
            # run test
            subprocess.run(base_cmd + test_file, check=True, shell=True, stdout=subprocess.PIPE)
            # compare if expected output was present
            if exp:
                equal = filecmp.cmp(test_file, test_file + '.expected_output')
                #self.assertTrue(equal, "Computed and expected output are not equal.")
        super(test_case_src, self).__init__(fn, methodName)

    def setUp(self):
        pass

    def tearDown(self):
        pass
        reset_test_dir(self.test_dir)




# same tests but run within singularity
#class test_unit_singularity(test_unit_src):
#    def setUp(self):
#        super().setUp()
#        self.snk_cmd = 'snakemake -j 4 --use-singularity --snakefile {snakefile} --directory {workdir} '.format(snakefile=os.path.join(self.repo_dir, 'Snakefile'), workdir=self.test_dir)


# main function
if __name__ == '__main__':
    cwd = os.getcwd()
    repo_dir = os.path.realpath(os.path.join(os.path.dirname(__file__), '../'))
    test_dir = 'test/test_src'
    snakefile = os.path.join(repo_dir, 'Snakefile')
    test_dir = init_test_dir(repo_dir, test_dir)
    reset_test_dir(test_dir)
    # load test cases
    with open(os.path.join(repo_dir, 'test', 'test_files.yaml'), 'r') as fp:
        try:
            test_cases = yaml.safe_load(fp)
        except yaml.YAMLError as exc:
            print(exc)
    suite = unittest.TestSuite()
    for module, module_tests in test_cases.items():
        for module_test in module_tests:
            suite.addTest(test_case_src(snakefile, module_test, methodName='test_{}_{}'.format(module, module_test)))
    runner = unittest.TextTestRunner()
    runner.run(suite)

    os.chdir(cwd)
    #unittest.main()
