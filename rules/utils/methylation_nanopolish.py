# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : nanopolish related helper
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
import os, sys, re


# iterator for nanopolish tsv output
class tsvParser():
    def __init__(self):
        pass

    def __parse_line__(self, line):
        cols = line.strip().split()
        chr, strand, begin, end, name, ratio, log_methylated, log_unmethylated, strands, n_cpgs, sequence = cols[:11]
        n_cpgs = int(n_cpgs)
        ratio = float(ratio)
        begin = int(begin)
        end = int(end)
        if n_cpgs == 1:
            sites = [(begin, end, ratio, log_methylated, log_unmethylated)]
        else:
            offsets = [m.start() for m in re.finditer('CG', sequence)]
            offsets[:] = [x - offsets[0] for x in offsets]
            sites = [(begin + offset, begin + offset, ratio, log_methylated, log_unmethylated) for offset in offsets]
        return name, chr, sites

    def records(self, iterable):
        it = iter(iterable)
        self.currentLine = next(it).strip()
        while True:
            if self.currentLine:
                sites = []
                name, chr, currentSites = self.__parse_line__(self.currentLine)
                sites.extend(currentSites)
                try:
                    self.currentLine = next(it).strip()
                except StopIteration:
                    yield name, chr, sites
                    return
                currentName, currentChr, currentSites = self.__parse_line__(self.currentLine)
                while name == currentName:
                    sites.extend(currentSites)
                    try:
                        self.currentLine = next(it).strip()
                    except StopIteration:
                        yield name, chr, sites
                        return
                    currentName, currentChr, currentSites = self.__parse_line__(self.currentLine)
                yield name, chr, sites
            else:
                return
