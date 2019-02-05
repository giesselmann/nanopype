# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : get file helper
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
import os

# flowcell and kit parsing
def get_ID(wildcards, config):
    fields = wildcards.runname.split(config['storage_runname']['delimiter'])
    return fields[config['storage_runname']['field_ID']]

def get_flowcell(wildcards, config):
    fields = wildcards.runname.split(config['storage_runname']['delimiter'])
    if len(fields) > config['storage_runname']['field_flowcell'] and fields[config['storage_runname']['field_flowcell']] in ['FLO-MIN106', 'FLO-MIN107', 'FLO-PRO001', 'FLO-PRO002']:
        flowcell = fields[config['storage_runname']['field_flowcell']]
        # TODO fix as soon as albacore supports FLO-PRO002
        if flowcell == 'FLO-PRO002':
            flowcell = 'FLO-PRO001'
        # end
        return fields[config['storage_runname']['field_flowcell']]
    else:
        raise ValueError('Could not detect flowcell from ' + wildcards.runname)

def get_kit(wildcards, config):
    fields = wildcards.runname.split(config['storage_runname']['delimiter'])
    if fields[config['storage_runname']['filed_kit']] in ['SQK-DCS108','SQK-LRK001','SQK-LSK108','SQK-LSK109', 'SQK-LSK308', 'SQK-LWB001','SQK-LWP001','SQK-PBK004','SQK-PCS108','SQK-PSK004','SQK-RAB201','SQK-RAB204','SQK-RAD002','SQK-RAD003','SQK-RAD004','SQK-RAS201','SQK-RBK001','SQK-RBK004','SQK-RLB001','SQK-RLI001','SQK-RNA001','SQK-RPB004','VSK-VBK001','VSK-VMK001','VSK-VSK001']:
        return fields[config['storage_runname']['filed_kit']]
    else:
        raise ValueError('Could not detect kit from ' + wildcards.runname)