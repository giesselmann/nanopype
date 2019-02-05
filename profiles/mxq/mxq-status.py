#!/usr/bin/env python3
# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : snakemake mxq status script
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
import sys, subprocess


if __name__ == '__main__':
    job_id = sys.argv[1]
    # mxqdump for job id
    try:
        ret = subprocess.run('mxqdump --job-id {job_id}'.format(job_id=job_id), check=True, shell=True, stdout=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        raise e
    # parse nxqdump output to dictionary
    out = ret.stdout.decode()
    status = {key:value for key, value in [line.split('=') for line in out.strip().split(' ')]}
    # summarize mxq status to snakemake codes
    if 'status' in status:
        status_code = status['status']
        if 'inq' in status_code or 'running' in status_code or 'loaded' in status_code or 'assigned' in status_code:
            print('running')
        elif 'finished' in status_code:
            print('success')
        else:
            print('failed')
        