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
    shadow: "minimal"
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
        src = directory("src/samtools")
    shadow: "minimal"
    shell:
        """
        cd src
        git clone https://github.com/samtools/samtools --branch 1.9 --depth=1
        cd samtools && autoheader --warning=none && autoconf -Wno-syntax && ./configure && make
        cp samtools ../../bin/
        """

rule minimap2:
    output:
        bin = "bin/minimap2",
        src = directory("src/minimap2")
    shadow: "minimal"
    shell:
        """
        cd src
        git clone https://github.com/lh3/minimap2 --branch v2.14 --depth=1
        cd minimap2 && make
        cp minimap2 ../../bin
        """

rule graphmap:
    output:
        bin = "bin/graphmap",
        src = directory("src/graphmap")
    shadow:"minimal"
    shell:
        """
        cd src
        git clone https://github.com/isovic/graphmap --branch master --depth=1
        cd graphmap && make modules && make
        cp bin/Linux-x64/graphmap ../../bin/
        """

rule ngmlr:
    output:
        bin = "bin/ngmlr",
        src = directory("src/ngmlr")
    shadow: "minimal"
    shell:
        """
        cd src
        git clone https://github.com/philres/ngmlr --branch v0.2.7 --depth=1
        mkdir -p ngmlr/build && cd ngmlr/build && cmake .. && make
        cp ../bin/*/ngmlr ../../../bin
        """

rule nanopolish:
    output:
        bin = "bin/nanopolish",
        src = directory("src/nanopolish")
    shadow: "minimal"
    shell:
        """
        cd src
        git clone --recursive https://github.com/jts/nanopolish --branch v0.10.2 --depth=1
        cd nanopolish && make
        cp nanopolish ../../bin/
        """

rule sniffles:
    output:
        bin = "bin/sniffles",
        src = directory("src/Sniffles")
    shadow: "minimal"
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

rule gitlfs:
    output:
        src = directory("src/git-lfs"),
        bin = "bin/git-lfs"
    shell:
        """
        cd src
        git clone https://github.com/git-lfs/git-lfs.git --branch v2.6.0 --depth=1
        cd git-lfs
        make
        cp bin/git-lfs ../../bin
        """
        
rule OpenBLAS:
    output:
        src = directory("src/OpenBLAS")
    shell:
        """
        cd src
        git clone https://github.com/xianyi/OpenBLAS --branch v0.3.4 --depth=1
        cd OpenBLAS
        make
        """
        
rule hdf5:
    output:
        src = directory("src/hdf5"),
    shell:
        """
        cd src
        git clone https://bitbucket.hdfgroup.org/scm/hdffv/hdf5.git --branch hdf5-1_8_20 --depth=1
        cd hdf5 && mkdir build
        install_prefix=`pwd`
        cd build
        cmake -DCMAKE_BUILD_TYPE=Release -DHDF5_ENABLE_Z_LIB_SUPPORT=ON -DHDF5_BUILD_TOOLS=OFF -DBUILD_TESTING=OFF -DHDF5_BUILD_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX=$install_prefix ../
        make
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
    params:
        hdf5_root = lambda wildcards, input : os.path.abspath(input.hdf5)
    shell:
        """
        {input.git_lfs} install
        cd src
        git clone https://github.com/nanoporetech/flappie
        cd flappie && mkdir build && cd build
        export PATH={input.blas}:{params.hdf5_root}:$PATH
        cmake -DCMAKE_BUILD_TYPE=Release -DOPENBLAS_ROOT={input.blas} -DHDF5_ROOT={params.hdf5_root} ../
        make
        cp flappie ../../../{output.bin}
        """