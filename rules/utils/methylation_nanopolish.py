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
# Copyright (c) 2018-2021, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
            sites = [(begin, end + 2, ratio, log_methylated, log_unmethylated)]
        else:
            offsets = [m.start() for m in re.finditer('CG', sequence)]
            offsets[:] = [x - offsets[0] for x in offsets]
            sites = [(begin + offset, begin + offset + 2, ratio, log_methylated, log_unmethylated) for offset in offsets]
        return name, chr, strand, sites

    def records(self, iterable):
        it = iter(iterable)
        self.currentLine = next(it).strip()
        while True:
            if self.currentLine:
                sites = []
                name, chr, strand, currentSites = self.__parse_line__(self.currentLine)
                sites.extend(currentSites)
                try:
                    self.currentLine = next(it).strip()
                except StopIteration:
                    yield name, chr, strand, sites
                    return
                currentName, currentChr, currentStrand, currentSites = self.__parse_line__(self.currentLine)
                while name == currentName and strand == currentStrand and chr == currentChr:
                    sites.extend(currentSites)
                    try:
                        self.currentLine = next(it).strip()
                    except StopIteration:
                        yield name, chr, strand, sites
                        return
                    currentName, currentChr, currentStrand, currentSites = self.__parse_line__(self.currentLine)
                yield name, chr, strand, sites
            else:
                return




if __name__ == '__main__':
    recordIterator = tsvParser()
    # skip header
    next(sys.stdin)
    # iterate input
    for name, chr, strand, sites in recordIterator.records(sys.stdin):
        for begin, end, ratio, log_methylated, log_unmethylated in sites:
            value = '1' if ratio >= 0 else '0'
            print('\t'.join([chr, str(begin), str(end), name, str(value), strand, str(ratio)]))
