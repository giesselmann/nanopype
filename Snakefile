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
# Copyright (c) 2018-2020, Pay Giesselmann, Max Planck Institute for Molecular Genetics
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
# imports
import os, sys, collections
import itertools
import yaml, subprocess
from snakemake.utils import min_version


# snakemake config
min_version("5.5.2")
configfile: "nanopype.yaml"


# get pipeline version
def get_tag():
    cmd = 'git describe --tags'
    try:
        version = subprocess.check_output(cmd.split(), cwd=os.path.dirname(workflow.snakefile)).decode().strip()
    except subprocess.CalledProcessError:
        raise RuntimeError('[ERROR] Unable to get version number from git tags.')
    if '-' in version:
        if hasattr(workflow, 'use_singularity') and workflow.use_singularity:
            print("[WARNING] You're using an untagged version of Nanopype with the Singularity backend. Make sure to also update the pipeline repository to avoid inconsistency between code and container.", file=sys.stderr)
        return 'latest'
    else:
        return version


nanopype_tag = get_tag()
config['version'] = {'tag': nanopype_tag}


# append username to shadow prefix if not present
if hasattr(workflow, "shadow_prefix") and workflow.shadow_prefix:
    shadow_prefix = workflow.shadow_prefix
    if not os.environ['USER'] in shadow_prefix:
        shadow_prefix = os.path.join(shadow_prefix, os.environ['USER'])
        print("[INFO] Shadow prefix is changed from {p1} to {p2} to be user-specific".format(
            p1=workflow.shadow_prefix, p2=shadow_prefix), file=sys.stderr)
    workflow.shadow_prefix = shadow_prefix


# parse pipeline environment
nanopype_env = {}
with open(os.path.join(os.path.dirname(workflow.snakefile), "env.yaml"), 'r') as fp:
    nanopype_env = yaml.load(fp)


# verify given references
if not 'references' in config:
    config['references'] = {}
if 'references' in nanopype_env:
    for name, values in nanopype_env['references'].items():
        genome = values['genome']
        chr_sizes = values['chr_sizes'] if 'chr_sizes' in values else ''
        if not os.path.isfile(genome):
            print("[WARNING] Genome for {name} not found in {genome}, skipping entry.".format(
                name=name, genome=genome), file=sys.stderr)
            continue
        if chr_sizes and not os.path.isfile(chr_sizes):
            print("[WARNING] Chromosome sizes for {name} not found in {chr_sizes}, skipping entry.".format(
                name=name, chr_sizes=chr_sizes), file=sys.stderr)
            continue
        config['references'][name] = {"genome":genome, "chr_sizes":chr_sizes}
else:
    print("[WARNING] No references in env.yaml. The alignment and downstream tools will not work.", file=sys.stderr)


# verify given binaries
if 'bin' in nanopype_env:
    if not 'bin' in config:
        config['bin'] = {}
    if not 'bin_singularity' in config:
        config['bin_singularity'] = {}
    for name, loc in nanopype_env['bin'].items():
        loc_sys = None
        loc_singularity = os.path.join('/usr/bin', os.path.basename(loc))
        if os.path.isfile(loc):
            # absolute path is given
            loc_sys = loc
        elif os.path.isfile(os.path.join(os.path.dirname(sys.executable), loc)):
            # executable in python installation/virtual environment
            loc_sys = os.path.join(os.path.dirname(sys.executable), loc)
        else:
            # scan the PATH if we find the executable
            for path in os.environ["PATH"].split(os.pathsep):
                f = os.path.join(path, os.path.basename(loc))
                if os.path.isfile(f):
                    loc_sys = f
        # save executable path depending on singularity usage
        if hasattr(workflow, 'use_singularity') and workflow.use_singularity:
            # within singularity everything is accessible through /bin
            config['bin_singularity'][name] = loc_singularity
            if loc_sys:
                config['bin'][name] = loc_sys
            else:
                print("[WARNING] {name} not found as {loc} and is only available in singularity rules.".format(
                    name=name, loc=loc), file=sys.stderr)
        else:
            # singularity rules use system wide executables
            if loc_sys:
                config['bin_singularity'][name] = loc_sys
                config['bin'][name] = loc_sys
            else:
                print("[WARNING] {name} not found as {loc} and is not available in the workflow.".format(
                    name=name, loc=loc), file=sys.stderr)
else:
    raise RuntimeError("[ERROR] No binaries in environment configuration.")


# Runtime scaling of data depending tools
if 'runtime' in nanopype_env:
    config['runtime'] = {}
    for key, value in nanopype_env['runtime'].items():
        config['runtime'][key] = value
else:
    raise RuntimeError("[ERROR] No runtime scalings in environment configuration.")


# memory scaling of data depending tools
if 'memory' in nanopype_env:
    config['memory'] = {}
    for key, value in nanopype_env['memory'].items():
        config['memory'][key] = tuple(value)
else:
    raise RuntimeError("[ERROR] No memory scalings in environment configuration.")


# locations of helper scripts in rules/utils
if not 'sbin' in config:
    config['sbin'] = {}
if not 'sbin_singularity' in config:
    config['sbin_singularity'] = {}
for s in [s for s in os.listdir(os.path.join(os.path.dirname(workflow.snakefile), 'rules/utils/')) if
        os.path.isfile(os.path.join(os.path.dirname(workflow.snakefile), 'rules/utils', s))]:
    if s.startswith('__') or s.startswith('.'):
        continue
    config['sbin'][s] = os.path.join(os.path.dirname(workflow.snakefile), 'rules/utils', s)
    if hasattr(workflow, 'use_singularity') and workflow.use_singularity:
        config['sbin_singularity'][s] = os.path.join('/app/rules/utils', s)
    else:
        config['sbin_singularity'][s] = config['sbin'][s]


# helper of submodules are called relative to the pipeline base directory
config['sbin']['base'] = os.path.join(os.path.dirname(workflow.snakefile))
if hasattr(workflow, 'use_singularity') and workflow.use_singularity:
    config['sbin_singularity']['base'] = '/app'
else:
    config['sbin_singularity']['base'] = config['sbin']['base']


# find the python executable
# Python executable of the workflow
config['bin']['python'] = sys.executable
# In the container we just use python3
if hasattr(workflow, 'use_singularity') and workflow.use_singularity:
	config['bin_singularity']['python'] = 'python3'
else:
	config['bin_singularity']['python'] = sys.executable


# names for multi-run rules
runnames = []
if os.path.isfile('runnames.txt'):
    runnames = [line.rstrip() for line in open('runnames.txt') if line.rstrip() and not line.startswith('#')]
config['runnames'] = runnames


# check raw data archive
if not os.path.exists(config['storage_data_raw']):
    raise RuntimeError("[ERROR] Raw data archive not found.")
else:
    for runname in config['runnames']:
        loc = os.path.join(config['storage_data_raw'], runname)
        if not os.path.exists(loc):
            print("[WARNING] {runname} not found at {loc} and is not available in the workflow.".format(
                runname=runname, loc=loc), file=sys.stderr)
        elif not os.path.exists(os.path.join(loc, 'reads')) or not os.listdir(os.path.join(loc, 'reads')):
            print("[WARNING] {runname} configured but with missing/empty reads directory.".format(
                runname=runname), file=sys.stderr)


# mount raw storage and references if using singularity
if hasattr(workflow, 'use_singularity') and workflow.use_singularity:
    if os.path.isabs(config['storage_data_raw']):
        workflow.singularity_args += " -B {}".format(config['storage_data_raw'])
    abs_paths = []
    # search for absolute paths, relative ones are below the working directory
    # and anyway mounted
    for name, ref in config['references'].items():
        genome = ref['genome']
        chr_sizes = ref['chr_sizes']
        abs_paths += [genome] if os.path.isabs(genome) else []
        abs_paths += [chr_sizes] if os.path.isabs(chr_sizes) else []
    # append paths to singularity mounts
    for mnt, paths in itertools.groupby(abs_paths, key=lambda x : x.split(os.path.sep)[0]):
        workflow.singularity_args += " -B {}".format(os.path.commonpath(list(paths)))
    # mount hosts tmpdir if declared
    if 'TMPDIR' in os.environ:
        workflow.singularity_args += " -B {}".format(os.environ["TMPDIR"])


# barcode mappings
barcodes = {}
if os.path.isfile('barcodes.yaml'):
    with open("barcodes.yaml", 'r') as fp:
        barcode_map = yaml.load(fp)
        barcodes = barcode_map
config['barcodes'] = barcodes


# region of interest tags
roi = {}
if os.path.isfile('roi.yaml'):
    with open("roi.yaml", 'r') as fp:
        roi_map = yaml.load(fp)
        roi = roi_map
config['roi'] = roi


# include modules
include : "rules/storage.smk"
include : "rules/basecalling.smk"
include : "rules/alignment.smk"
include : "rules/methylation.smk"
include : "rules/sv.smk"
include : "rules/demux.smk"
include : "rules/transcript.smk"
include : "rules/clean.smk"
