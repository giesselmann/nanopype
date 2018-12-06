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
#  All rights reserved to Max Planck Institute for Molecular Genetics
#  Berlin, Germany
#  Written by Pay Giesselmann
# -----------------------------------------------------------------------
import os, sys
import site
from setuptools import setup
from setuptools.command.install import install
from setuptools.command.develop import develop
from setuptools.command.egg_info import egg_info


class AppendPathCmd(install):
    user_options = install.user_options + [
        ('tools=', None, None), 
    ]
    def initialize_options(self):
        install.initialize_options(self)
        self.tools = None
        #self.someval = None

    def finalize_options(self):
        print("value of tools is", self.tools)
        install.finalize_options(self)
        
    def run(self):
        with open(os.path.join(site.getsitepackages()[0], 'nanopype.pth'), 'w') as fp:
            print('import os; os.environ["PATH"] += os.pathsep + "{dir}"'.format(dir=os.path.abspath(self.tools)), file=fp)

        
setup(
    name='nanopype',
    version='0.0.1',
    author='Pay Giesselmann',
    author_email='giesselmann@molgen.mpg.de',
    description='Nanopore data processing workflows',
    long_description=open('README.md').read(),
    url='https://github.com/giesselmann/nanopype',
    license='LICENSE',
    python_requires='>=3.4',
    install_requires=['snakemake>=5.3.0', 'h5py>=2.7.1', 'watchdog'],
    include_package_data=True,
    scripts=['scripts/nanopype_import.py',],
    zip_safe=False,
    cmdclass={
        'install': AppendPathCmd
    }
)