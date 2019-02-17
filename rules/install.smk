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
# Copyright (c) 2018-2019, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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

rule alignment:
    input:
        "bin/minimap2",
        "bin/graphmap",
        "bin/ngmlr",
        "bin/samtools"

rule methylation:
    input:
        "bin/nanopolish",
        "bin/samtools",
        "bin/bedtools",
        "bin/bedGraphToBigWig"


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

if not 'build_generator' in config:
    config['build_generator'] = '"Unix Makefiles"'

if not 'flappie_src' in config:
    config['flappie_src'] = True

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
        bin = "bin/bedtools"
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d bedtools2 ]; then
            git clone https://github.com/arq5x/bedtools2 --branch v2.27.1 --depth=1 && cd bedtools2
        else
            cd bedtools2 && git fetch --all --tags --prune && git checkout tags/v2.27.1
        fi
        make clean && make
        cp bin/bedtools ../../bin/
        """

rule htslib:
    output:
        src = directory("src/htslib")
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d htslib ]; then
            git clone https://github.com/samtools/htslib --branch 1.9 --depth=1 && cd htslib
        else
            cd htslib && git fetch --all --tags --prune && git checkout tags/1.9
        fi
        autoheader && autoconf && ./configure && make -j{threads}
        """

rule samtools:
    input:
        rules.htslib.output.src
    output:
        bin = "bin/samtools"
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d samtools ]; then
            git clone https://github.com/samtools/samtools --branch 1.9 --depth=1 && cd samtools
        else
            cd samtools && git fetch --all --tags --prune && git checkout tags/1.9
        fi
        autoheader --warning=none && autoconf -Wno-syntax && ./configure && make -j{threads}
        cp samtools ../../bin/
        """

rule minimap2:
    output:
        bin = "bin/minimap2"
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d minimap2 ]; then
            git clone https://github.com/lh3/minimap2 --branch v2.14 --depth=1 && cd minimap2
        else
            cd minimap2 && git fetch --all --tags --prune && git checkout tags/v2.14
        fi
        make clean && make -j{threads}
        cp minimap2 ../../bin
        """

rule graphmap:
    output:
        bin = "bin/graphmap"
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d graphmap ]; then
            git clone https://github.com/isovic/graphmap --branch master --depth=1 && cd graphmap
        else
            cd graphmap && git fetch --all --tags --prune && git checkout master
        fi
        make modules -j{threads} && make -j{threads}
        cp bin/Linux-x64/graphmap ../../bin/
        """

rule ngmlr:
    output:
        bin = "bin/ngmlr"
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d ngmlr ]; then
            git clone https://github.com/philres/ngmlr --branch v0.2.7 --depth=1 && cd ngmlr
        else
            cd ngmlr && git fetch --all --tags --prune && git checkout tags/v0.2.7
        fi
        mkdir -p build && cd build && rm -rf * && cmake -DCMAKE_BUILD_TYPE=Release -G {config[build_generator]} .. && cmake --build . --config Release -- -j {threads}
        cp ../bin/*/ngmlr ../../../bin
        """

rule nanopolish:
    output:
        bin = "bin/nanopolish"
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d nanopolish ]; then
            git clone --recursive https://github.com/jts/nanopolish --branch v0.11.0 --depth=1 && cd nanopolish
        else
            cd nanopolish && git fetch --all --tags --prune && git checkout tags/v0.11.0
        fi
        make clean
        make -j{threads}
        cp nanopolish ../../bin/
        """

rule sniffles:
    output:
        bin = "bin/sniffles"
    threads: config['threads_build']
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d Sniffles ]; then
            git clone https://github.com/fritzsedlazeck/Sniffles --branch v1.0.10 --depth=1 && cd Sniffles
        else
            cd Sniffles && git fetch --all --tags --prune && git checkout tags/v1.0.10
        fi
        mkdir -p build && cd build && rm -rf * && cmake -DCMAKE_BUILD_TYPE=Release -G{config[build_generator]} .. && cmake --build . --config Release -- -j {threads}
        cp ../bin/*/sniffles ../../../bin
        """

rule deepbinner:
    output:
        bin = "bin/deepbinner-runner.py"
    shell:
        """
        mkdir -p src && cd src
        if [ ! -d Deepbinner ]; then
            git clone https://github.com/rrwick/Deepbinner --branch v0.2.0 --depth=1 && cd Deepbinner
        else
            cd Deepbinner && git fetch --all --tags --prune && git checkout tags/v0.2.0
        fi
        pip3 install -r requirements.txt --upgrade
        ln -s $(pwd)/deepbinner-runner.py ../../{output.bin}
        """

rule golang:
    output:
        src = directory("src/go/bin")
    shell:
        """
        mkdir -p src && cd src
        wget -nc https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz
        tar -xzf go1.11.2.linux-amd64.tar.gz
        """

rule gitlfs:
    input:
        go = lambda wildcards : find_go() if find_go() is not None else rules.golang.output.src
    output:
        bin = "bin/git-lfs"
    shell:
        """
        export PATH=$(pwd)/{input.go}:$PATH
        mkdir -p src && cd src
        if [ ! -d git-lfs ]; then
            git clone https://github.com/git-lfs/git-lfs.git --branch v2.6.0 --depth=1 && cd git-lfs
        else
            cd git-lfs && git fetch --all --tags --prune && git checkout tags/v2.6.0
        fi
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
        mkdir -p src && cd src
        if [ ! -d OpenBLAS ]; then
            git clone https://github.com/xianyi/OpenBLAS --branch v0.3.4 --depth=1 && cd OpenBLAS
        else
            cd OpenBLAS && git fetch --all --tags --prune && git checkout tags/v0.3.4
        fi
        make clean && make NO_LAPACK=1 NOFORTRAN=1 -j{threads}
        make install PREFIX=$install_prefix
        """

rule hdf5:
    output:
        src = directory("src/hdf5")
    threads: config['threads_build']
    shell:
        """
        install_prefix=`pwd`
        mkdir -p src && cd src
        if [ ! -d hdf5 ]; then
            git clone https://bitbucket.hdfgroup.org/scm/hdffv/hdf5.git --branch hdf5-1_8_20 --depth=1 && cd hdf5
        else
            cd hdf5 && git fetch --all --tags --prune && git checkout tags/hdf5-1_8_20
        fi
        mkdir -p build && cd build && rm -rf * && cmake -DCMAKE_BUILD_TYPE=Release -DHDF5_ENABLE_Z_LIB_SUPPORT=ON -DHDF5_BUILD_TOOLS=OFF -DBUILD_TESTING=OFF -DHDF5_BUILD_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX=$install_prefix -G{config[build_generator]} ../
        cmake --build . --config Release -- -j {threads}
        cmake --build . --config Release --target install
        """

rule Flappie:
    input:
        lambda wildcards,config=config: [rules.gitlfs.output.bin] +
        ([rules.OpenBLAS.output.src] if config['flappie_src'] else []) +
        ([rules.hdf5.output.src] if config['flappie_src'] else [])
    output:
        bin = "bin/flappie"
    threads: config['threads_build']
    shell:
        """
        install_prefix=`pwd`
        bin/git-lfs install
        export PATH=$install_prefix/bin:$PATH
        mkdir -p src && cd src
        if [ ! -d flappie ]; then
            git clone https://github.com/nanoporetech/flappie --branch master && cd flappie
        else
            cd flappie && git fetch --all --tags --prune && git checkout master
        fi
        mkdir -p build && cd build && rm -rf * && cmake -DCMAKE_BUILD_TYPE=Release -DOPENBLAS_ROOT=$install_prefix -DHDF5_ROOT=$install_prefix -G{config[build_generator]} ../
        cmake --build . --config Release -- -j {threads}
        cp flappie ../../../{output.bin}
        """

rule Guppy:
    output:
        bin = "bin/guppy_basecaller"
    shell:
        """
        wget https://mirror.oxfordnanoportal.com/software/analysis/ont-guppy-cpu_2.3.1_linux64.tar.gz && \
        tar --skip-old-files -xzf ont-guppy-cpu_2.3.1_linux64.tar.gz -C / --strip 1 && \
        rm ont-guppy-cpu_2.3.1_linux64.tar.gz
        """
