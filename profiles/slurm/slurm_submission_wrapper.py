#! /usr/bin/env python

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
              "".format(mem=s_mem,
                        time=s_time,
                        threads=job_properties['threads'],
                        rule=s_rule,
                        jobid=s_jobid,
                        script=jobscript)

sys.stderr.write(sbatch_line + '\n')

os.system(sbatch_line)
