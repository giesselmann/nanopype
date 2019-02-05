# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
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
# snakemake config
configfile: "config.yaml"
import os, sys, collections


# helper
# https://stackoverflow.com/questions/3232943/update-value-of-a-nested-dictionary-of-varying-depth
def update(d, u):
    for k, v in u.items():
        if isinstance(v, collections.Mapping):
            d[k] = update(d.get(k, {}), v)
        else:
            d[k] = v
    return d


# append username to shadow prefix if not present
if hasattr(workflow, "shadow_prefix") and workflow.shadow_prefix:
    shadow_prefix = workflow.shadow_prefix
    if not os.environ['USER'] in shadow_prefix:
        shadow_prefix = os.path.join(shadow_prefix, os.environ['USER'])
    workflow.shadow_prefix = shadow_prefix


# parse pipeline environment
import os, yaml
with open(os.path.join(os.path.dirname(workflow.snakefile), "env.yaml"), 'r') as fp:
    nanopype_env = yaml.load(fp)
    # check tool access and convert to absolute paths, cluster jobs might run with different PATH settings
    nanopype_env_glob = {}
    nanopype_env_glob['bin'] = {}
    for name, loc in nanopype_env['bin'].items():
        tool_found = False
        # if already global path
        if os.path.isfile(nanopype_env['bin'][name]):
            nanopype_env_glob['bin'][name] = loc
            tool_found = True
        # check bin of python executable
        elif os.path.isfile(os.path.join(os.path.dirname(sys.executable), nanopype_env['bin'][name])):
            nanopype_env_glob['bin'][name] = os.path.join(os.path.dirname(sys.executable), nanopype_env['bin'][name])
            tool_found = True
        # check the remaining PATH
        else:
            for path in os.environ["PATH"].split(os.pathsep):
                exe_file = os.path.join(path, os.path.basename(nanopype_env['bin'][name]))
                if os.path.isfile(exe_file):
                    nanopype_env_glob['bin'][name] = exe_file
                    tool_found = True
        if not tool_found:
            #raise EnvironmentError(name + " not found in PATH")
            print(' '.join(["[WARNING]", name, 'not executable or found in PATH']), file=sys.stderr)
    nanopype_env.update(nanopype_env_glob)
    config = update(config, nanopype_env)


# multi-run rules
runnames = []
if os.path.isfile('runnames.txt'):
    runnames = [line.rstrip('\n') for line in open('runnames.txt')]
config['runnames'] = runnames


# include modules
include : "rules/storage.smk"
include : "rules/basecalling.smk"
include : "rules/alignment.smk"
include : "rules/methylation.smk"
include : "rules/sv.smk"
include : "rules/demux.smk"
