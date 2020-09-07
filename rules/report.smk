# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : pipeline pdf report rules
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
import snakemake
import itertools
from rules.utils.report import nanopype_report
# local rules
localrules: report_disk_usage, report_sequences, report_alignments_stats
localrules: report_alignments_coverage, report




def get_alignment_summary_report(wildcards):
    batch_files = snakemake.utils.listfiles('alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}/{batch, [^.]*}.{reference, [^.]*}.bam')
    def key_fun(x):
        wc = x[1]
        return (wc.aligner, wc.sequence_workflow, wc.tag, wc.runname, wc.reference)
    batch_files = sorted(list(batch_files), key=key_fun)
    summary_files = ['alignments/{}/{}/batches/{}/{}.{}.hdf5'.format(*key) for key, values in itertools.groupby(batch_files, key=key_fun) if key[3] in config['runnames']]
    return summary_files




def configure_seaborn(sns):
    sns.set_palette("colorblind")
    sns.set_context("paper", font_scale=1.4, rc={
        "lines.linewidth": 0.75})
    sns.set_style("white", rc={
        #'axes.edgecolor': 'white',
        #'patch.edgecolor': 'white',
        #'axes.spines.linewidth': 0.5,
        'axes.spines.right': False,
        'axes.spines.top': False})




# disk usage of raw and processing data
rule report_disk_usage:
    input:
        runs = lambda wildcards : [os.path.join(config['storage_data_raw'], runname) for runname in config['runnames']],
        modules = lambda wildcards : [m for m in
            ['sequences', 'alignments', 'methylation', 'sv', 'transcript', 'assembly']
            if os.path.isdir(m)]
    output:
        'report/stats/disk_usage.hdf5'
    run:
        import os
        import pandas as pd
        from pathlib import Path

        def du(root_dir='.'):
            root_dir = Path(root_dir)
            return sum(f.stat().st_size for f in root_dir.glob('**/*') if f.is_file())

        raw = sum(du(os.path.join(config['storage_data_raw'], runname)) for runname in config['runnames'])
        modules = [du(m) for m in input.modules]
        df = pd.DataFrame(data={'name' : ['raw'] + input.modules, 'bytes' : [raw] + modules})
        df.to_hdf(output[0], 'disk_usage')




# sequence statistics
checkpoint report_sequences:
    input:
        lambda wildcards : [x[0] + '.hdf5' for x in snakemake.utils.listfiles('sequences/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^\/]*}') if os.path.isdir(x[0]) and x[1].runname in set(config['runnames'])]
    output:
        stats = directory('report/stats/sequences'),
        plot = directory('report/plots/sequences')
    run:
        import os, glob
        import snakemake
        import numpy as np
        import pandas as pd
        import matplotlib as mpl
        mpl.use('Agg')
        from matplotlib import pyplot as plt
        import seaborn as sns

        configure_seaborn(sns)

        # stats per workflow and tag
        workflows = snakemake.utils.listfiles('sequences/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}')
        workflows = sorted(list(workflows), key=lambda x: x[1].sequence_workflow)
        run_id = {runname:i for i, runname in enumerate(config['runnames'])}
        os.makedirs(output.stats, exist_ok=True)
        os.makedirs(output.plot, exist_ok=True)

        # plots
        summary = []
        df_list = []
        def n50(df):
            return df[df.throughput > (df.throughput.iloc[-1] / 2)].length.iloc[0]
        for sequence_workflow, values in itertools.groupby(workflows, lambda x: x[1].sequence_workflow):
            f, ax = plt.subplots(ncols=2, figsize=(10,5), constrained_layout=True)
            values = list(values)
            n_groups = len(values)
            for tag_folder, tag_wildcards in values:
                tag_inputs = list(snakemake.utils.listfiles('sequences/{sequence_workflow}/batches/{tag}/{runname}.hdf5'.format(sequence_workflow=sequence_workflow, tag=tag_wildcards.tag, runname='{runname, [^\/]*}')))
                if not tag_inputs:
                    continue
                df = pd.concat([pd.read_hdf(f).assign(
                        Flowcell=lambda x: run_id[wc.runname],
                        Tag=lambda x: tag_wildcards.tag,
                        Basecalling=lambda x: sequence_workflow) for f, wc in tag_inputs if wc.runname in config['runnames']])
                df_list.append(df)
                df.sort_values(by='length', inplace=True)
                df['throughput'] = df.length.cumsum()
                xlim = df[df.throughput > (0.90 * df.throughput.iloc[-1])].length.iloc[0]
                xlim *= 1.1
                label = '{tag}'.format(tag=tag_wildcards.tag)
                # read length histogramm up to 90% of throughput
                sns.distplot(df.length, kde=False,
                    hist_kws={'range': (0, xlim), 'alpha': 0.5 + (0.5 / n_groups)},
                    label=label,
                    ax=ax[0])
                # cumulative throughput over read length
                sns.lineplot(x='length', y='throughput',
                    label=label,
                    data=df[df.length < xlim].iloc[np.linspace(0, df[df.length < xlim].shape[0]-1, 1000).astype(int)],
                    ax=ax[1])
                summary.append((tag_wildcards.tag, sequence_workflow,
                                df.length.sum(),
                                df.length.mean(), df.length.median(),
                                n50(df), df.length.max()
                                ))
            ax[0].set_xlabel('Read length')
            ax[0].set_ylabel('Reads')
            ax[0].legend()
            ax[1].set_xlabel('Read length')
            ax[1].set_ylabel('Throughput')
            ax[1].legend()
            f.suptitle("Read length distribution and cumulative throughput")
            f.savefig(os.path.join(output.plot, 'sequences1_{}.svg'.format(sequence_workflow)))

        if len(summary):
            df_total = pd.concat(df_list)
            df_total_agg = df_total.groupby(['Basecalling', 'Tag', 'Flowcell']).agg(
                Total=('length', 'sum')
            ).reset_index()
            for bc in df_total_agg.Basecalling.unique():
                f, ax = plt.subplots(nrows=2, figsize=(10,5), sharex=True, constrained_layout=True)
                # Barplot with throughput per flow cell
                sns.barplot(x='Flowcell', y='Total', hue='Tag', data=df_total_agg[df_total_agg.Basecalling == bc], errwidth=0, ax=ax[0])
                ax[0].set_ylabel('Throughput')
                ax[0].set_xlabel('')
                # Read length distribution per flow cell
                sns.boxplot(x="Flowcell", y="length", hue="Tag", showfliers=False, data=df_total[df_total.Basecalling == bc], ax=ax[1])
                ax[1].set_ylabel('Read length')
                ax[1].set_xlabel('Flow cell')
                f.suptitle("Total basepairs and read lengths per flow cell")
                f.savefig(os.path.join(output.plot, 'sequences2_{}.svg'.format(bc)))
            df_summary = pd.DataFrame(summary, columns=['Tag', 'Basecalling', 'Sum', 'Mean', 'Median', 'N50', 'Maximum'])
            df_summary.to_hdf(os.path.join(output.stats, 'sequences.hdf5'), 'sequences')




# alignment statistics
checkpoint report_alignments_stats:
    input:
        lambda wildcards : get_alignment_summary_report(wildcards)
    output:
        plot = directory('report/plots/alignments/')
    run:
        import itertools
        import snakemake
        import numpy as np
        import pandas as pd
        import matplotlib as mpl
        mpl.use('Agg')
        from matplotlib import pyplot as plt
        import seaborn as sns

        configure_seaborn(sns)
        os.makedirs(output.plot, exist_ok=True)

        run_id = {runname:i for i, runname in enumerate(config['runnames'])}
        run_files = sorted(list(snakemake.utils.listfiles('alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}/{runname, [^.\/]*}.{reference, [^.]*}.hdf5')), key=lambda x: (x[1].sequence_workflow, x[1].tag))
        df_list = []
        for (sequence_workflow, tag), values in itertools.groupby(run_files, key=lambda x: (x[1].sequence_workflow, x[1].tag)):
            df = pd.concat([pd.read_hdf(f).assign(
                    Basecaller=lambda x: sequence_workflow,
                    Aligner=lambda x: w.aligner,
                    Tag=lambda x: w.tag,
                    Flowcell=lambda x: run_id[w.runname],
                    Reference=lambda x: w.reference) for f, w in values])
            df['Mapping'] = df.flag.apply(lambda x : 'unmapped' if (x & 0x4) else 'secondary' if (x & 0x100) or (x & 0x800) else 'primary' if (x == 0) or (x == 0x10) else 'unknown')
            if 'identity' in df.columns:
                df_agg = df.groupby(['Basecaller', 'Tag', 'Aligner', 'Flowcell', 'Reference', 'Mapping', 'ID']).agg(
                    length=('length', 'first'),
                    mapped_length=('mapped_length', 'median'),
                    Identity=('identity', 'median')
                ).reset_index().drop(columns=['ID'])
            else:
                df_agg = df.groupby(['Basecaller', 'Tag', 'Aligner', 'Flowcell', 'Reference', 'Mapping', 'ID']).agg(
                    length=('length', 'first'),
                    mapped_length=('mapped_length', 'median')
                ).reset_index().drop(columns=['ID'])
                df_agg['Identity'] = 0
            df_list.append(df_agg)
            # mapping rate by read numbers
            g = sns.catplot("Mapping", hue='Aligner', col="Reference",
                data=df_agg, kind="count", height=5, aspect=1.0)
            g.fig.subplots_adjust(wspace=.05, hspace=0.5)
            (g.set_axis_labels("Mapping", "Reads"))
            g.savefig(os.path.join(output.plot, 'alignments_counts_{}_{}.svg'.format(sequence_workflow, tag)))
        # mapping rate by cumulative length
        df_agg = pd.concat(df_list)
        df_agg['Mapped %'] = df_agg['mapped_length'] / df_agg['length']
        df_agg_primary = df_agg[df_agg.Mapping == 'primary'].copy()
        df_agg_primary.sort_values(by=['Tag', 'Basecaller', 'Aligner', 'Reference', 'length'], inplace=True)
        df_agg_primary_grouper = df_agg_primary.groupby(['Tag', 'Basecaller', 'Aligner', 'Reference'], sort=False)
        df_agg_primary = df_agg_primary.assign(**{'Sequenced Bases' : df_agg_primary_grouper['length'].cumsum(), 'Mapped Bases': df_agg_primary_grouper['mapped_length'].cumsum()})
        xlim = df_agg_primary[df_agg_primary['Mapped Bases'] > (0.95 * df_agg_primary['Mapped Bases'].max())].length.iloc[0]
        xlim *= 1.1
        df_agg_primary.set_index('Basecaller', inplace=True)
        for bc in df_agg_primary.index.unique():
            df_subset = df_agg_primary.loc[bc]
            g = sns.relplot(x="length", y="Mapped Bases", hue='Aligner', style='Tag', col="Reference",
                data=df_subset[df_subset.length < xlim].iloc[np.linspace(0, df_subset[df_subset.length < xlim].shape[0]-1, 1000).astype(int)], kind='line', height=5, aspect=1.0)
            g.fig.subplots_adjust(wspace=.05, hspace=0.5)
            (g.set_axis_labels("Read length", "Mapped Bases"))
            g.savefig(os.path.join(output.plot, 'alignments_bases_{}.svg'.format(bc)))
            # read identity if available
            # TODO this will fail if one aligner sets the NM-tag and the other not
            if df_subset.Identity.sum() > 0:
                g = sns.catplot(x="Flowcell", y="Identity", hue='Tag', row="Reference",
                    data=df_subset, kind='violin', kwargs={'cut': 0}, height=2.5, aspect=4)
                g.fig.subplots_adjust(wspace=.05, hspace=0.5)
                (g.set_axis_labels("Flow cell", "BLAST identity")
                .set(ylim=(0,1)))
                g.savefig(os.path.join(output.plot, 'alignments_identity_{}.svg'.format(bc)))




# coverage track per chromosome
checkpoint report_alignments_coverage:
    input:
        lambda wildcards : [x[0] for x in snakemake.utils.listfiles('alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bedGraph')]
    output:
        plot = directory('report/plots/coverage')
    run:
        import re
        import pandas as pd
        import matplotlib as mpl
        mpl.use('Agg')
        from matplotlib import pyplot as plt
        import seaborn as sns

        configure_seaborn(sns)
        os.makedirs(output.plot, exist_ok=True)

        for cov_file, cov_wc in snakemake.utils.listfiles('alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bedGraph'):
            df = pd.read_csv(cov_file, sep='\t', header=None, names=['chr', 'begin', 'end', 'coverage'])
            df['bin'] = df['begin'] // (df.begin.max() / 1000)
            def sort_key(k):
                return ''.join(re.findall(r'\D+', k) + ['{:05d}'.format(int(m)) for m in re.findall(r'\d+', k)])

            df_agg = df.groupby(['chr', 'bin']).agg(
                pos=('begin', 'first'),
                end=('end', 'last'),
                coverage=('coverage', 'median')
            ).reset_index()
            df_agg['key'] = df_agg.chr.map(sort_key)
            df_agg = df_agg.sort_values(by=['key', 'pos']).drop(columns=['key'])
            # coverage per chromosome
            g = sns.FacetGrid(df_agg, col="chr", hue='chr', col_wrap=4, sharex=True, sharey=True, height=1, aspect=2.5)
            g = (g.map(plt.plot, "pos", "coverage", marker=".", lw=0, markersize=0.2)
                .set(ylim=(0, df_agg.coverage.mean() * 2.0))
                .set_titles("{col_name}"))
            g.fig.subplots_adjust(wspace=.05, hspace=0.5)
            g.savefig(os.path.join(output.plot, 'coverage_{}_{}_{}_{}.svg'.format(
                cov_wc.aligner, cov_wc.sequence_workflow, cov_wc.tag, cov_wc.reference)))




# summary from methylation calls
checkpoint report_methylation:
    input:
        lambda wildcards : [x[0] for x in snakemake.utils.listfiles('methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.\/]*}.frequencies.tsv.gz')]
    output:
        plot = directory('report/plots/methylation/')
    run:
        import os, itertools
        import snakemake
        import pandas as pd
        import matplotlib as mpl
        mpl.use('Agg')
        from matplotlib import pyplot as plt
        import seaborn as sns

        configure_seaborn(sns)
        os.makedirs(output.plot, exist_ok=True)

        workflows = snakemake.utils.listfiles('methylation/{methylation_caller, [^.\/]*}/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.\/]*}.frequencies.tsv.gz')
        df_list = []
        df_agg_list = []
        for frequencies, wildcards in workflows:
            df = pd.read_csv(frequencies, sep='\t', header=None, compression='gzip', names=['chr', 'begin', 'end', 'level', 'coverage'])
            df.sort_values('coverage', inplace=True)
            df_agg = df.groupby('coverage', sort=False).agg(
                count=('coverage', 'count')
            ).reset_index().sort_values('coverage', ascending=False)
            df_agg['total'] = df_agg['count'].cumsum()
            df_agg['Methylation caller'] = wildcards.methylation_caller
            df_agg['Aligner'] = wildcards.aligner
            df_agg['Basecaller'] = wildcards.sequence_workflow
            df_agg['Tag'] = wildcards.tag
            df_agg['Reference'] = wildcards.reference
            df_agg_list.append(df_agg)
        # plots
        if df_agg_list:
            df_agg = pd.concat(df_agg_list)
            df_agg.set_index(['Basecaller', 'Aligner'], inplace=True)
            for basecaller, aligner in df_agg.index.unique():
                df_subset = df_agg.loc[basecaller, aligner]
                g = sns.relplot(x="coverage", y="total",
                     col="Reference", hue="Methylation caller", style="Tag",
                     kind="line", height=5, aspect=1.0,
                     data=df_subset[df_subset.total > (df_subset.total.max() * 0.05)])
                g.fig.subplots_adjust(wspace=.05, hspace=0.5)
                (g.set_axis_labels("Coverage threshold", "CpGs"))
                g.savefig(os.path.join(output.plot, 'coverage_{}_{}.svg'.format(aligner, basecaller)))




# main report
rule report:
    input:
        disk_usage = rules.report_disk_usage.output,
        sequences = rules.report_sequences.output,
        alignments = rules.report_alignments_stats.output,
        coverage = rules.report_alignments_coverage.output,
        methylation = rules.report_methylation.output
    output:
        pdf = 'report.pdf'
    run:
        import os
        import pandas as pd
        report = nanopype_report(os.getcwd(), output.pdf, version=config['version']['full-tag'])
        # summary
        summary_table = []
        summary_table.append(('{:d}'.format(len(config['runnames'])), 'Flow cells'))
        f_sequences_stats = 'report/stats/sequences/sequences.hdf5'
        df_sequences = pd.read_hdf(f_sequences_stats) if os.path.isfile(f_sequences_stats) else None
        if df_sequences is not None:
            for field, label, scale, unit in zip(['Sum', 'N50'], ['Total bases', 'N50'], [1e9, 1e3], ['GB', 'kB']):
                if df_sequences.shape[0] < 2:
                    summary_table.append(('{:.1f} {}'.format(df_sequences[field][0] / scale, unit), label))
                else:
                    summary_table.append(('{:.1f} to {:.1f} {}'.format(df_sequences[field].min() / scale, df_sequences[field].max() / scale, unit), label))
        df_disk_usage = pd.read_hdf(input.disk_usage[0])
        summary_table.append(('{:.2f} GB'.format(df_disk_usage.bytes.sum() / 1e9), 'Total disk usage'))
        report.add_summary(summary_table)
        # flow cells
        report.add_section_flowcells(config['runnames'])
        # sequences
        f_sequences_plots = snakemake.utils.listfiles('report/plots/sequences/sequences{i}_{basecalling}.svg')
        report.add_section_sequences(f_sequences_plots, df_sequences)
        # alignments
        f_alignments_counts = [(x[0], "Basecalling: {} ({})".format(x[1].sequence_workflow, x[1].tag)) for x in snakemake.utils.listfiles('report/plots/alignments/alignments_counts_{sequence_workflow, [^_]*}_{tag}.svg')]
        f_alignments_bases = [(x[0], "Basecalling: {}".format(x[1].sequence_workflow)) for x in snakemake.utils.listfiles('report/plots/alignments/alignments_bases_{sequence_workflow}.svg')]
        f_alignments_identity = [(x[0], "Basecalling: {}".format(x[1].sequence_workflow)) for x in snakemake.utils.listfiles('report/plots/alignments/alignments_identity_{sequence_workflow}.svg')]
        f_alignments_coverage = [x[0] for x in snakemake.utils.listfiles('report/plots/coverage/coverage_{tag}.svg')]
        report.add_section_alignments(counts=f_alignments_counts,
                        bases=f_alignments_bases,
                        identity=f_alignments_identity,
                        coverage=f_alignments_coverage)
        # methylation
        f_methylation_coverage = [(x[0], "Basecalling: {}, Alignment: {}".format(x[1].sequence_workflow, x[1].aligner)) for x in snakemake.utils.listfiles('report/plots/methylation/coverage_{aligner}_{sequence_workflow}.svg')]
        report.add_section_methylation(coverage=f_methylation_coverage)
        # build report pdf
        report.build()
