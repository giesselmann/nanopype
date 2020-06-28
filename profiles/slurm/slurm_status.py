#! /usr/bin/env python

import subprocess
import sys

jobid = sys.argv[1]

output = str(subprocess.check_output("sacct -j %s --format=State --noheader | head -1 | awk '{print $1}'" % jobid,
                                     shell=True).strip())

running_status=["PENDING", "CONFIGURING", "COMPLETING", "RUNNING", "SUSPENDED"]
if "COMPLETED" in output:
    print("success")
elif any(r in output for r in running_status):
    print("running")
else:
    sys.stderr.write('\n'
                     'Something went wrong.\n'
                     'Check the log files, including Slurm logs'
                     ' (something like "log/cluster/{rule}.{jobid}.%j.log").\n')
    print("failed")
