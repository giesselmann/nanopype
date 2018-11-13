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

configfile: "config.yaml"


localrules: all, basecaller_merge, aligner_merge_run, nanopolish_methylation_merge_run, nanopolish_methylation_merge_runs, nanopolish_methylation_frequencies


def get_batches(wildcards):
    batches, = glob_wildcards("{datadir}/{wildcards.runname}/reads/{{id}}.tar".format(datadir=config["DATADIR"], wildcards=wildcards))
    return batches

def get_batches_basecaller(wildcards):
    return expand("runs/{wildcards.runname}/sequences/{{batch}}.{wildcards.basecaller}.{wildcards.format}".format(wildcards=wildcards), batch=get_batches(wildcards))
    
def get_batches_aligner(wildcards):
    return expand("runs/{wildcards.runname}/alignments/{{batch}}.{wildcards.aligner}.bam".format(wildcards=wildcards), batch=get_batches(wildcards))    

def get_batches_methylation(wildcards):
    return expand("runs/{wildcards.runname}/methylation/{{batch}}.{wildcards.methylation_caller}.tsv".format(wildcards=wildcards), batch=get_batches(wildcards))    


#
# Basecalling
#
rule albacore:
    output:
        "runs/{runname}/sequences/{batch}.albacore.{format}",
    shadow: "minimal"
    threads: 16
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.1 * (attempt - 1))) * 32000),
        time_min = 60
    params:
        flowcell="FLO-MIN106",
        kit="SQK-LSK108"
    shell:
        """
        mkdir -p raw
        tar -C raw/ -xf {config[DATADIR]}/{wildcards.runname}/reads/{wildcards.batch}.tar
        {config[albacore]} -i raw/ --recursive -t {threads} -s raw/ --flowcell {params.flowcell} --kit {params.kit} --output_format fastq --disable_filtering
        find raw/workspace/ -regextype posix-extended -regex '^.*f(ast)?q' -exec cat {{}} \; > {wildcards.batch}.fq
        if [[ {wildcards.format} == *'q'* ]]
        then
            cat {wildcards.batch}.fq > {output}
        else
            cat {wildcards.batch}.fq | paste - - - - | cut -f1,2 | tr '@' '>' | tr '\t' '\n' > {output}
        fi
        """
        
rule basecaller_merge:
    input:
        get_batches_basecaller
    output:
        "runs/{runname, [a-zA-Z0-9_-]+}.{basecaller}.{format, (fasta|fastq|fa|fq)}"
    shell:
        "cat {input} > {output}"
        
        
        

#
# Alignment
#
rule minimap2:
    input:
        "runs/{runname}/sequences/{batch}.albacore.fa"
    output:
        bam = "runs/{runname}/alignments/{batch}.minimap2.bam",
        bai = "runs/{runname}/alignments/{batch}.minimap2.bam.bai"
    shadow: "minimal"
    threads: 16
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.1 * (attempt - 1))) * 32000),
        time_min = 240
    shell:
        """
        {config[minimap2]} -ax map-ont {config[reference]} {input} -t {threads} | {config[samtools]} view -Sb - | {config[samtools]} sort -m 4G > {output.bam}
        {config[samtools]} index {output.bam}
        """

rule graphmap:
    input:
        "runs/{runname}/sequences/{batch}.albacore.fa"
    output:
        bam = "runs/{runname}/alignments/{batch}.graphmap.bam",
        bai = "runs/{runname}/alignments/{batch}.graphmap.bam.bai"
    shadow: "minimal"
    threads: 16
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.1 * (attempt - 1))) * 80000),
        time_min = 240
    shell:
        """
        {config[graphmap]} align -r {config[reference]} -d {input} -t {threads} -B 100 | {config[samtools]} view -Sb - | {config[samtools]} sort -m 4G > {output.bam}
        {config[samtools]} index {output.bam}
        """
        
rule aligner_merge_run:
    input:
        get_batches_aligner
    output:
        "runs/{runname, [a-zA-Z0-9_-]+}.{aligner}.bam"
    shell:
        """
        {config[samtools]} merge {output} {input}
        {config[samtools]} index {output}
        """
    
    
    
    
#
# methylation detection
#
rule nanopolish_methylation:
    input:
        sequences = "runs/{runname}/sequences/{batch}.albacore.fa",
        bam = "runs/{runname}/alignments/{batch}.graphmap.bam",
        bai = "runs/{runname}/alignments/{batch}.graphmap.bam.bai"
    output:
        "runs/{runname}/methylation/{batch}.nanopolish.tsv"
    shadow: "minimal"
    threads: 16
    resources:
        mem_mb = lambda wildcards, attempt: int((1.0 + (0.1 * (attempt - 1))) * 32000),
        time_min = 120
    shell:
        """
        mkdir -p raw
        tar -C raw/ -xf {config[DATADIR]}/{wildcards.runname}/reads/{wildcards.batch}.tar
        {config[nanopolish]} index -d raw/ {input.sequences}
        {config[nanopolish]} call-methylation -t {threads} -r {input.sequences} -g {config[reference]} -b {input.bam} > {output}
        """
        
rule nanopolish_methylation_merge_run:
    input:
        get_batches_methylation
    output:
        "runs/{runname, [a-zA-Z0-9_-]+}.{methylation_caller}.tsv"
    run:
        from scripts.nanopolish import tsvParser
        recordIterator = tsvParser()
        with open(output[0], 'w') as fp_out:
            for ip in input:
                with open(ip, 'r') as fp_in:
                    # skip header
                    next(fp_in)
                    # iterate input
                    for name, chr, sites in recordIterator.records(iter(fp_in)):
                        for begin, end, ratio, log_methylated, log_unmethylated in sites:
                            print('\t'.join([chr, str(begin), str(end), name, str(ratio), str(log_methylated), str(log_unmethylated)]), file=fp_out)

rule nanopolish_methylation_merge_runs:
    input:
        ['runs/{runname}.nanopolish.tsv'.format(runname=runname) for runname in config["runs"]]
                            
rule nanopolish_methylation_frequencies:
    input:
        "runs/{runname}.{methylation_caller}.tsv"
    output:
        "runs/{runname, [a-zA-Z0-9_-]+}.{methylation_caller}.bedGraph"
    params:
        log_p_threshold = 2.5
    shell:
        """
        cat {input} | cut -f1-3,5 | perl -anle 'if(abs($F[3]) > {params.log_p_threshold}){{if($F[3]>{params.log_p_threshold}){{print join("\t", @F[0..2], "1")}}else{{print join("\t", @F[0..2], "0")}}}}' | sort -k1,1 -k2,2n | {config[bedtools]} groupby -g 1,2,3 -c 4 -o mean > {output}
        """

        
        
