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
import os, sys, glob, argparse, yaml
import subprocess
import unittest
import filecmp, shutil, wget
import urllib.request
from test_base import test_case_base




base_url = 'https://owww.molgen.mpg.de/~nanopype/unit_tests/{}'




# initialize test dir with git repo to restore original state after each test
def init_test_dir(repo_dir, test_dir='.', config={}, runnames=[]):
    #if os.path.exists(test_dir) and os.listdir(test_dir):
    #    raise RuntimeError("Test directory {} is not empty.".format(test_dir))
    os.makedirs(test_dir, exist_ok=True)
    os.chdir(test_dir)
    # get list of filenames
    fofn_url = base_url.format('index.fofn')
    files = [file for file in urllib.request.urlopen(fofn_url).read().decode('utf-8').split('\n') if file]
    # download files from
    for file in files:
        file_dir = os.path.dirname(file)
        if file_dir:
            os.makedirs(file_dir, exist_ok=True)
        if os.path.isfile(file):
            os.remove(file)
        wget.download(base_url.format(file), file, bar=None)
    # write runnames.txt
    with open('runnames.txt', 'w') as fp:
        print('\n'.join(runnames), file=fp)
    # copy nanopype.yaml from repo
    with open(os.path.join(repo_dir, 'nanopype.yaml'), 'r') as fp:
        base_config = yaml.safe_load(fp)
    base_config.update(config)
    with open('nanopype.yaml', 'w') as fp:
        print(yaml.dump(base_config, sort_keys=True), file=fp)
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




# reset test dir to downloaded state
def reset_test_dir(test_dir='.'):
    subprocess.run('git reset --hard', check=True, shell=True, stdout=subprocess.PIPE)
    subprocess.run('git clean -f -d', check=True, shell=True, stdout=subprocess.PIPE)




# test case
class test_case_src(test_case_base):
    def __init__(self, snakefile, test_file,
                test_dir='.', threads=1, singularity=False,
                methodName='none', keep=False):
        self.test_dir = test_dir
        self.keep = keep
        base_cmd = 'snakemake -j {threads}{flags} --snakefile {snakefile} --directory {test_dir} '.format(
            threads=max(2, threads),
            flags=' --use-singularity --singularity-args=" -u"' if singularity else '',
            snakefile=snakefile,
            test_dir=test_dir)
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
        if not self.keep:
            reset_test_dir(self.test_dir)

    def tearDown(self):
        pass




# main function
if __name__ == '__main__':
    # cmd arguments
    parser = argparse.ArgumentParser(description="Nanopype raw data import script",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("suite", choices=['DNA', 'cDNA', 'mRNA'], help='Test suite to load')
    parser.add_argument("module", choices=
        ['all', 'storage',
         'basecalling', 'alignment', 'methylation',
         'sv', 'assembly',
         'transcript_isoforms',
         'report'],
        help="Modules to test in selected suite")
    parser.add_argument("dir", help="Working directory for tests")
    parser.add_argument('-t', '--threads', type=int, default=4, help="Threads for parallel tests")
    parser.add_argument("--singularity", action="store_true", help="Use singularity version")
    parser.add_argument('--keep', action="store_true", help="Do not reset working directory after each test")
    args = parser.parse_args()
    # save current workdir
    cwd = os.getcwd()
    # init and reset test dir with data and git repository
    repo_dir = os.path.realpath(os.path.join(os.path.dirname(__file__), '../'))
    test_dir = args.dir
    snakefile = os.path.join(repo_dir, 'Snakefile')
    # load test cases
    with open(os.path.join(repo_dir, 'test', 'test_config.yaml'), 'r') as fp:
        try:
            test_config = yaml.safe_load(fp)
        except yaml.YAMLError as exc:
            print(exc, file=sys.stderr)
            exit(-1)
    suite = unittest.TestSuite()
    suite_config = test_config['test_suites'].get(args.suite)
    if suite_config is None:
        print("Test suite {} not configured. Nothing to do.".format(args.suite), file=sys.stderr)
        exit(0)
    assert suite_config is not None
    runnames = suite_config.get('runnames') or []
    config = suite_config.get('config') or {}
    test_dir = init_test_dir(repo_dir, test_dir, config=config, runnames=runnames)
    for module, module_tests in suite_config['test_cases'].items():
        if args.module == 'all' or args.module == module:
            for module_test in module_tests:
                suite.addTest(test_case_src(snakefile, module_test,
                    test_dir=test_dir,
                    threads=args.threads,
                    singularity=args.singularity,
                    keep=args.keep,
                    methodName='test_{}_{}'.format(module, module_test)))
    # execute tests
    runner = unittest.TextTestRunner()
    result = runner.run(suite)
    # back to initial workdir
    os.chdir(cwd)
    # return depending on result
    if result.wasSuccessful():
        exit(0)
    else:
        exit(1)
