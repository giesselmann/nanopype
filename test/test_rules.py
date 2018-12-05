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
import os, glob, unittest, yaml
import subprocess
import urllib.request


# Test cases
class test_unit_rules(unittest.TestCase):
    def setUp(self):
        self.repo_dir = os.path.dirname(os.path.abspath(os.path.join(__file__, '..')))
        self.test_dir = os.path.join(self.repo_dir, 'test')
        # make data directory and extract test reads
        data_dir = os.path.join(self.test_dir, 'data', 'raw')
        os.makedirs(data_dir, exist_ok=True)
        subprocess.run('tar -xzf {archive} -C {data_dir}'.format(archive=os.path.join(self.test_dir, 'test_data.tar.gz'),data_dir=data_dir), check=True, shell=True, stdout=subprocess.PIPE)
        # download reference fasta
        ref_dir = os.path.join(self.test_dir, 'references')
        os.makedirs(ref_dir, exist_ok=True)
        ref_file = os.path.join(ref_dir, 'chr6.fa')
        if not os.path.isfile(ref_file):
            urllib.request.urlretrieve('http://hgdownload.cse.ucsc.edu/goldenpath/hg38/chromosomes/chr6.fa.gz', ref_file + '.gz')
            subprocess.run('gzip -d {ref_file}.gz'.format(ref_file=ref_file), check=True, shell=True, stdout=subprocess.PIPE)
        size_file = os.path.join(ref_dir, 'chr6.sizes')
        if not os.path.isfile(size_file):
            urllib.request.urlretrieve('http://hgdownload.cse.ucsc.edu/goldenPath/hg38/bigZips/hg38.chrom.sizes', size_file)
        # modify config and copy to workdir
        with open(os.path.join(self.test_dir, '..', 'config.yaml'), 'r') as fp:
            try:
                default_config = yaml.load(fp)
            except yaml.YAMLError as exc:
                print(exc)
        default_config['storage_data_raw'] = data_dir
        with open(os.path.join(self.test_dir, 'config.yaml'), 'w') as fp:
            yaml.dump(default_config, fp, default_flow_style=False)
        # create readnames file
        runnames = [os.path.basename(f) for f in glob.glob(os.path.join(data_dir, '*'))]
        with open(os.path.join(self.test_dir, 'runnames.txt'), 'w') as fp:
            for runname in runnames:
                print(runname, file=fp)
        self.snk_cmd = 'snakemake -j 4 --snakefile {snakefile} --directory {workdir} '.format(snakefile=os.path.join(self.repo_dir, 'Snakefile'), workdir=self.test_dir)

    # test indexing
    def test_storage(self):
        subprocess.run(self.snk_cmd + 'storage_index_runs', check=True, shell=True)

    # Test basecaller functionality
    def test_basecalling(self):
        subprocess.run(self.snk_cmd + 'test.albacore.fa.gz', check=True, shell=True)

    # Test alignment
    def test_alignment(self):
        subprocess.run(self.snk_cmd + 'test.minimap2.test.bam', check=True, shell=True)
        subprocess.run(self.snk_cmd + 'test.graphmap.test.bam', check=True, shell=True)
        subprocess.run(self.snk_cmd + 'test.ngmlr.test.bam', check=True, shell=True)

    def test_methylation(self):
        subprocess.run(self.snk_cmd + 'test.1x.nanopolish.test.bw', check=True, shell=True)

    def test_sv(self):
        subprocess.run(self.snk_cmd + "test.ngmlr.test.sniffles.vcf", check=True, shell=True)

# main function
if __name__ == '__main__':
    unittest.main()
