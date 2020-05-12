# \BUILD\---------------------------------------------------------------
#
#  CONTENTS      : Python installer for nanopype
#
#  DESCRIPTION   : Distutils installation of nanopype pipeline
#
#  RESTRICTIONS  : none
#
#  REQUIRES      : none
#
# -----------------------------------------------------------------------
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
import os, sys, shutil
import site
import setuptools
from setuptools import setup
from setuptools.command.install import install
from setuptools.command.develop import develop
from setuptools.command.egg_info import egg_info


def run_cstm_cmd(self):
    # append binary folder to PYTHON PATH
    if self.tools:
        with open(os.path.join(site.getsitepackages()[0], 'nanopype.pth'), 'w') as fp:
            print('import os; os.environ["PATH"] = "{dir}" + os.pathsep + os.environ["PATH"]'.format(dir=os.path.abspath(self.tools)), file=fp)


class CustomInstallCmd(install):
    user_options = install.user_options + [
        ('tools=', None, None),
    ]
    def initialize_options(self):
        install.initialize_options(self)
        self.tools = None

    def run(self):
        install.run(self)
        run_cstm_cmd(self)


setup(
    name='nanopype',
    version='0.10.0',
    author='Pay Giesselmann',
    author_email='giesselmann@molgen.mpg.de',
    description='Nanopore data processing workflows',
    long_description=open('README.md').read(),
    url='https://github.com/giesselmann/nanopype',
    license='LICENSE',
    python_requires='>=3.5',
    install_requires=open('requirements.txt').read().split('\n'),
    include_package_data=True,
    scripts=['scripts/nanopype_import.py',],
    zip_safe=False,
    cmdclass={
        'install': CustomInstallCmd
    }
)
