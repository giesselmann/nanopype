#! /usr/bin/env python

# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : snakemake slurm submission script
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
# Written by Miguel Machado
# ---------------------------------------------------------------------------------

import os
import sys

from snakemake.utils import read_job_properties


jobscript = sys.argv[1]
job_properties = read_job_properties(jobscript)

if not os.path.isdir('log/cluster/'):
    os.makedirs('log/cluster')

s_rule = 'rule'
if 'rule' in job_properties:
    s_rule = job_properties['rule']
elif 'groupid' in job_properties:
    s_rule = job_properties['groupid']

s_jobid = 'jobid'
if 'jobid' in job_properties:
    s_jobid = job_properties['jobid']

s_mem = 1024
if 'mem_mb' in job_properties['resources']:
    s_mem = job_properties['resources']['mem_mb']

s_time = ''
if 'time_min' in job_properties['resources']:
    s_time = '--time={}'.format(job_properties['resources']['time_min'])

sbatch_line = "sbatch --parsable" \
              " --nodes=1 --ntasks=1 --cpus-per-task={threads}" \
              " --mem={mem}M" \
              " {time}" \
              " --job-name={rule}.{jobid}" \
              " --output=log/cluster/{rule}.{jobid}.%j.log {script}" \
              "".format(threads=job_properties['threads'],
                        mem=s_mem,
                        time=s_time,
                        rule=s_rule,
                        jobid=s_jobid,
                        script=jobscript)

sys.stderr.write(sbatch_line + '\n')

os.system(sbatch_line)
