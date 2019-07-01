# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : nanopore transcript rules
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

# identify full length cDNA reads
checkpoint pychopper:
    input:
        seq = "sequences/{basecaller}/batches/{batch}.{format}.gz"
        #prmr = ""
    output:
        seq = "sequences/pychopper/{basecaller, [^.\/]*}/batches/{batch, [^.]*}.{format, (fastq|fq)}.gz"
    shadow: "minimal"
    threads: 1
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (3000 + 1000 * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt) # 90 min / 16 threads
    singularity:
        "docker://nanopype/transcript:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        mkfifo input_seq
        mkfifo output_seq
        zcat {input.seq} > input_seq &
        {config[bin_singularity][python]} {config[bin_singularity][cdna_classifier]} -b {input.prmr} input_seq output_seq &
        cat output_seq | gzip > {output.seq}
        """

# spliced alignment to gff
rule pinfish:
    input:
        bam = "alignments/{aligner}/{sequence_workflow}/{tag}.{reference}.bam",
        bai = "alignments/{aligner}/{sequence_workflow}/{tag}.{reference}.bam.bai",
        reference = lambda wildcards: config['references'][wildcards.reference]['genome']
    output:
        gff = "transcript_isoforms/pinfish/{aligner, [^.\/]*}/{sequence_workflow}/{tag, [^.\/]*}.{reference, [^.\/]*}.gff"
    threads: config['threads_transcript']
    shadow: 'minimal'
    resources:
        mem_mb = lambda wildcards, threads, attempt: int((1.0 + (0.1 * (attempt - 1))) * (config['memory']['pinfish'][0] + config['memory']['pinfish'][1] * threads)),
        time_min = lambda wildcards, threads, attempt: int((1440 / threads) * attempt * config['runtime']['pinfish']) # 90 min / 16 threads
    singularity:
        "docker://nanopype/transcript:{tag}".format(tag=config['version']['tag'])
    shell:
        """
        racon_dir=`dirname {config[bin_singularity][racon]}`
        minimap_dir=`dirname {config[bin_singularity][minimap2]}`
        samtools_dir=`dirname {config[bin_singularity][samtools]}`
        PATH=$racon_dir:$minimap_dir:samtools_dir:$PATH
        TMPDIR=`pwd`
        echo 'splicing initial alignment'
        {config[bin_singularity][spliced_bam2gff]} {config[transcript_spliced_bam2gff_flags]} -M -t {threads} {input.bam} > raw_transcript.gff
        echo 'cluster gff'
        {config[bin_singularity][cluster_gff]} {config[transcript_cluster_gff_flags]} -t {threads} -a cluster_transcript.tsv raw_transcript.gff > cluster_transcript.gff
        echo 'collapse cluster'
        {config[bin_singularity][collapse_partials]} {config[transcript_collapse_partials]} -t {threads} cluster_transcript.gff > cluster_collapsed.gff
        echo 'polish collapsed cluster'
        {config[bin_singularity][polish_clusters]} {config[transcript_polish_clusters]} -d $(pwd) -a cluster_transcript.tsv -t {threads} -o cluster_polish.fasta {input.bam}
        echo 'map collapsed polished cluster to reference'
        {config[bin_singularity][minimap2]} -t {threads} {config[alignment_minimap2_flags]} {input.reference} cluster_polish.fasta |         {config[bin_singularity][samtools]} view -Sb -F 2304 | {config[bin_singularity][samtools]} sort -o cluster_polish.{wildcards.reference}.bam -
        {config[bin_singularity][samtools]} index cluster_polish.{wildcards.reference}.bam
        {config[bin_singularity][spliced_bam2gff]} {config[transcript_spliced_bam2gff_flags]} -M -t {threads} cluster_polish.{wildcards.reference}.bam > cluster_polish.gff
        echo 'collapse mapped transcripts'
        {config[bin_singularity][collapse_partials]} {config[transcript_collapse_partials]} -t {threads} cluster_polish.gff > {output.gff}
        """
