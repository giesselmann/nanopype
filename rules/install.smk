# \SCRIPT\-------------------------------------------------------------------------
#
#  CONTENTS      : download, build and install tools
#
#  DESCRIPTION   : none
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
# main build rules
import os

rule default:
    shell : ""

rule core:
    input:
        "bin/flappie",
        "bin/bedtools",
        "bin/samtools",
        "bin/minimap2",
        "bin/graphmap",
        "bin/ngmlr",
        "bin/nanopolish",
        "bin/bedGraphToBigWig"

rule extended:
    input:
        "bin/sniffles",
        "bin/deepbinner-runner.py"

rule all:
    input:
        rules.core.input,
        rules.extended.input
        
# helper functions
def find_go():
    for path in os.environ["PATH"].split(os.pathsep):
        exe_file = os.path.join(path, 'go')
        if os.path.isfile(exe_file):
            return path
    return None

# defaults
if not 'threads_build' in config:
    config['threads_build'] = 1

# detailed build rules
rule UCSCtools:
    output:
        "bin/bedGraphToBigWig"
    shell:
        """
        wget -O {output} ftp://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig
        chmod 755 {output}
        """

rule bedtools:
    output:
        bin = "bin/bedtools",
        src = directory("src/bedtools2")
    shell:
        """
        cd src
        git clone https://github.com/arq5x/bedtools2 --branch v2.27.1 --depth=1
        cd bedtools2 && make
        cp bin/bedtools ../../bin/
        """

rule htslib:
    output:
        src = directory("src/htslib")
    shell:
        """
        cd src
        git clone https://github.com/samtools/htslib --branch 1.9 --depth=1
        cd htslib && autoheader && autoconf && ./configure && make
        """

rule samtools:
    input:
        rules.htslib.output.src
    output:
        bin = "bin/samtools",
    shell:
        """
        cd src
        git clone https://github.com/samtools/samtools --branch 1.9 --depth=1
        cd samtools && autoheader --warning=none && autoconf -Wno-syntax && ./configure && make
        cp samtools ../../bin/
        """

rule minimap2:
    output:
        bin = "bin/minimap2"
    shell:
        """
        cd src
        git clone https://github.com/lh3/minimap2 --branch v2.14 --depth=1
        cd minimap2 && make
        cp minimap2 ../../bin
        """

rule graphmap:
    output:
        bin = "bin/graphmap"
    shell:
        """
        cd src
        git clone https://github.com/isovic/graphmap --branch master --depth=1
        cd graphmap && make modules && make
        cp bin/Linux-x64/graphmap ../../bin/
        """

rule ngmlr:
    output:
        bin = "bin/ngmlr"
    shell:
        """
        cd src
        git clone https://github.com/philres/ngmlr --branch v0.2.7 --depth=1
        mkdir -p ngmlr/build && cd ngmlr/build && cmake .. && make
        cp ../bin/*/ngmlr ../../../bin
        """

rule nanopolish:
    output:
        bin = "bin/nanopolish"
    threads: config['threads_build']
    shell:
        """
        cd src
        git clone --recursive https://github.com/jts/nanopolish --branch v0.10.2 --depth=1
        cd nanopolish && make -j{threads}
        cp nanopolish ../../bin/
        """

rule sniffles:
    output:
        bin = "bin/sniffles"
    shell:
        """
        cd src
        git clone https://github.com/fritzsedlazeck/Sniffles --branch v1.0.10 --depth=1
        mkdir -p Sniffles/build && cd Sniffles/build && cmake .. && make
        cp ../bin/*/sniffles ../../../bin
        """

rule deepbinner:
    output:
        bin = "bin/deepbinner-runner.py",
        src = directory("src/Deepbinner")
    shell:
        """
        cd src
        git clone https://github.com/rrwick/Deepbinner --branch v0.2.0 --depth=1
        cd Deepbinner
        pip3 install -r requirements.txt
        ln -s $(pwd)/deepbinner-runner.py ../../{output.bin}
        """

rule golang:
    output:
        src = directory("src/go/bin")
    shell:
        """
        cd src
        wget -nc https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz
        tar -xzf go1.11.2.linux-amd64.tar.gz
        """

rule gitlfs:
    input:
        go = lambda wildcards : find_go() if find_go() is not None else rules.golang.output.src
    output:
        src = directory("src/git-lfs"),
        bin = "bin/git-lfs"
    shell:
        """
        export PATH=$(pwd)/{input.go}:$PATH
        cd src
        git clone https://github.com/git-lfs/git-lfs.git --branch v2.6.0 --depth=1
        cd git-lfs
        make
        cp bin/git-lfs ../../bin
        """

rule OpenBLAS:
    output:
        src = directory("src/OpenBLAS")
    threads: config['threads_build']
    shell:
        """
        install_prefix=`pwd`
        cd src
        git clone https://github.com/xianyi/OpenBLAS --branch v0.3.4 --depth=1
        cd OpenBLAS
        make NO_LAPACK=1 -j{threads}
        make install PREFIX=$install_prefix
        """

rule hdf5:
    output:
        src = directory("src/hdf5")
    threads: config['threads_build']
    shell:
        """
        install_prefix=`pwd`
        cd src
        git clone https://bitbucket.hdfgroup.org/scm/hdffv/hdf5.git --branch hdf5-1_8_20 --depth=1
        cd hdf5 && mkdir build
        cd build
        cmake -DCMAKE_BUILD_TYPE=Release -DHDF5_ENABLE_Z_LIB_SUPPORT=ON -DHDF5_BUILD_TOOLS=OFF -DBUILD_TESTING=OFF -DHDF5_BUILD_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX=$install_prefix –GNinja ../
        cmake --build . --config Release -- -j 8
        make install
        """

rule Flappie:
    input:
        git_lfs = rules.gitlfs.output.bin,
        blas = rules.OpenBLAS.output.src,
        hdf5 = rules.hdf5.output.src
    output:
        src = directory("src/flappie"),
        bin = "bin/flappie"
    threads: config['threads_build']
    shell:
        """
        install_prefix=`pwd`
        {input.git_lfs} install
        export PATH=$install_prefix:$PATH
        cd src
        git clone https://github.com/nanoporetech/flappie
        cd flappie && mkdir build && cd build
        cmake -DCMAKE_BUILD_TYPE=Release -DOPENBLAS_ROOT=$install_prefix -DHDF5_ROOT=$install_prefix –GNinja ../
        cmake --build . --config Release -- -j {threads}
        cp flappie ../../../{output.bin}
        """
