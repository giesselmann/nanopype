# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : Raw data storage, indexing, extraction etc.
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
localrules: storage_index_run, storage_extract

# fast5 signal location
LOC_RAW = "/Raw/"


def get_batches_indexing(wildcards):
    return expand("{data_raw}/{wildcards.runname}/reads/{{batch}}.fofn".format(data_raw = config["storage_data_raw"], wildcards=wildcards), batch=get_batches(wildcards))


# extract read ID from individual fast5 files
rule storage_index_batch:
    input:
        "{data_raw}/{{runname}}/reads/{{batch}}.tar".format(data_raw = config["storage_data_raw"])
    output:
        temp("{data_raw}/{{runname}}/reads/{{batch}}.fofn".format(data_raw = config["storage_data_raw"]))
    shadow: "minimal"
    threads: 1
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.1 * (attempt - 1))) * 4000),
        time_min = 15
    run:
        import os, subprocess, h5py
        os.mkdir('reads')
        subprocess.run('tar -C reads/ -xf {input}'.format(input=input), check=True, shell=True, stdout=subprocess.PIPE)
        f5files = [os.path.join(dirpath, f) for dirpath, _, files in os.walk('reads/') for f in files if f.endswith('.fast5')]
        with open(output[0], 'w') as fp_out:
            # scan files 
            for f5file in f5files:
                try:
                    with h5py.File(f5file, 'r') as f5:
                        s = f5[LOC_RAW].visit(lambda name: name if 'Signal' in name else None)
                        ID = str(f5[LOC_RAW + '/' + s.rpartition('/')[0]].attrs['read_id'], 'utf-8')
                        print('\t'.join([os.path.join('reads', wildcards.batch + '.tar', os.path.relpath(f5file, start='./reads')), ID]), file=fp_out)
                except:
                    pass
 
# merge batch indices
rule storage_index_run:
    input:
        get_batches_indexing
    output:
        "{data_raw}/{{runname}}/reads.fofn".format(data_raw = config["storage_data_raw"])
    shell:
        """
        cat {input} > {output}
        """
        
# extract reads from indexed run
rule storage_extract:
    input:
        index = "{data_raw}/{{runname}}/reads.fofn".format(data_raw = config["storage_data_raw"]),
        names = "subset/{tag}.txt"
    output:
        directory("subset/{tag, [^./]*}/{runname, [^./]*}")
    run:
        import os, itertools, tarfile
        # read target names
        ids = []
        with open(input.names, 'r') as fp:
            for line in fp:
                ids.append(line.strip())
        # read index
        records = {}
        with open(input.index, 'r') as fp:
            records = {read_ID:filename for filename, read_ID in [line.rstrip().split('\t')[0:2] for line in fp]}
        # lookup file locations per ID
        batches = [file.rpartition(".tar/") for file in [records[id] for id in ids if id in records]]
        batches.sort(key = lambda x : x[0])
        # group and extract per batch
        for archive, batch in itertools.groupby(batches, key= lambda x : x[0]):
            tarFiles = [os.path.basename(x[2]) for x in batch]
            try:
                with tarfile.open(os.path.join(config["storage_data_raw"], wildcards.runname, archive + ".tar")) as tar:
                    tar_members = tar.getmembers()
                    for tar_member in tar_members:
                        if any(s in tar_member.name for s in tarFiles):
                            try:
                                tar_member.name = os.path.basename(tar_member.name)
                                tar.extract(tar_member, path=output[0])
                            except:
                                print("Failed to extract " + tar_member.name + 'from batch' + archive)
            except:
                print("Failed to open batch " + archive)


# extract reads from indexed runs
rule storage_extract_multi:
    input:
        names = "subset/{tag}.txt",
        files = lambda wildcards : [directory("subset/{tag}/{runname}".format(tag=wildcards.tag, runname=rn)) for rn in config['runnames']]
    output:
        touch("subset/{tag}.done")
    run:
        print(input.files)
        