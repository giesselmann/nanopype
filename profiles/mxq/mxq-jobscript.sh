#!/bin/sh
# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : snakemake jobscript
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
# properties = {properties}
H=${{HOSTNAME/.molgen.mpg.de/}}
J=${{MXQ_JOBID:-${{PID}}}}
DATE=`date +%Y%m%d`

mkdir -p log/cluster
# parse snakemake command, replace newlines
cmd=$(echo """{exec_job}""" | sed 's/\\\n //')

# modify /scratch/local2 to tmpdir prefix
# e.g. --shadow-prefix /scratch/local2/giesselm
if [ -n "$MXQ_JOB_TMPDIR" ]; then
    cmd=$(echo $cmd | sed -E 's@--shadow-prefix [^ ]+@--shadow-prefix '"${{MXQ_JOB_TMPDIR}}@");
fi

echo "Job command is:"
echo $cmd
(eval $cmd) &> log/cluster/${{DATE}}_${{H}}_${{J}}.log
