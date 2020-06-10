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
# https://www.blog.pythonlibrary.org/2013/08/12/reportlab-how-to-add-page-numbers/
# https://github.com/zopefoundation/z3c.rml
import snakemake
import itertools
from rules.utils.report import nanopype_report




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
        import seaborn as sns
        from matplotlib import pyplot as plt
        sns.set_palette("colorblind")
        # stats per workflow and tag
        workflows = snakemake.utils.listfiles('sequences/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}')
        os.makedirs(output.stats, exist_ok=True)
        os.makedirs(output.plot, exist_ok=True)
        # plots
        summary = []
        df_list = []
        def n50(df):
            return df[df.throughput > (df.throughput.iloc[-1] / 2)].length.iloc[0]
        for group, values in itertools.groupby(workflows, lambda x: x[1].sequence_workflow):
            for tag_folder, tag_wildcards in values:
                df = pd.concat([pd.read_hdf(d).assign(
                        Flowcell=lambda x: i,
                        Tag=lambda x: tag_wildcards.tag,
                        Basecalling=lambda x: tag_wildcards.sequence_workflow) for i, d in enumerate(input)])
                df_list.append(df)
                df.sort_values(by='length', inplace=True)
                df['throughput'] = df.length.cumsum()
                xlim = df.length.quantile(0.95)
                xlim *= 1.1
                label = '{tag}'.format(tag=tag_wildcards.tag)
                f, ax = plt.subplots(ncols=2, figsize=(10,5), constrained_layout=True)
                sns.distplot(df.length, kde=False,
                    hist_kws={'range': (0, xlim)},
                    label=label,
                    ax=ax[0])
                sns.lineplot(x='length', y='throughput',
                    label=label,
                    data=df[df.length < xlim].iloc[np.linspace(0, df[df.length < xlim].shape[0]-1, 1000).astype(int)],
                    ax=ax[1])
                summary.append((tag_wildcards.tag, tag_wildcards.sequence_workflow,
                                df.length.sum(),
                                df.length.mean(), df.length.median(),
                                n50(df), df.length.max()
                                ))
                ax[0].set_ylabel('Reads')
                ax[0].set_xlabel('Read length')
                ax[0].legend()
                ax[1].set_ylabel('Throughput')
                ax[1].set_xlabel('Read length')
                ax[1].legend()
                f.suptitle("Read length distribution and cumulative throughput")
                f.savefig(os.path.join(output.plot, 'sequences1_{}.svg'.format(tag_wildcards.sequence_workflow)))

        if len(summary):
            df_total = pd.concat(df_list)
            df_total_agg = df_total.groupby(['Basecalling', 'Tag', 'Flowcell']).agg(
                Total=('length', 'sum')
            ).reset_index()
            for bc in df_total_agg.Basecalling.unique():
                f, ax = plt.subplots(nrows=2, figsize=(10,5), sharex=True, constrained_layout=True)
                sns.barplot(x='Flowcell', y='Total', hue='Tag', data=df_total_agg[df_total_agg.Basecalling == bc], errwidth=0, ax=ax[0])
                ax[0].set_ylabel('Throughput')
                ax[0].set_xlabel('')
                sns.boxplot(x="Flowcell", y="length", hue="Tag", showfliers=False, data=df_total[df_total.Basecalling == bc], ax=ax[1])
                ax[1].set_ylabel('Read length')
                ax[1].set_xlabel('Flow cell')
                f.suptitle("Total basepairs and read lengths per flow cell")
                f.savefig(os.path.join(output.plot, 'sequences2_{}.svg'.format(bc)))
            df_summary = pd.DataFrame(summary, columns=['Tag', 'Basecalling', 'Sum', 'Mean', 'Median', 'N50', 'Maximum'])
            df_summary.to_hdf(os.path.join(output.stats, 'sequences.hdf5'), 'sequences')




checkpoint report_alignments_coverage:
    input:
        lambda wildcards : [x[0] for x in snakemake.utils.listfiles('alignments/{aligner, [^.\/]*}/{sequence_workflow, ((?!batches).)*}/{tag, [^\/]*}.{reference, [^.]*}.bedGraph')]
    output:
        plot = directory('report/plots/alignments/coverage')
    run:
        import re
        import pandas as pd
        import seaborn as sns
        from matplotlib import pyplot as plt

        sns.set_palette("colorblind")
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

            g = sns.FacetGrid(df_agg, col="chr", hue='chr', col_wrap=4, sharex=True, sharey=True, height=1, aspect=2.5)
            g = (g.map(plt.plot, "pos", "coverage", marker=".", lw=0, markersize=0.2)
                .set(ylim=(0, df_agg.coverage.mean() * 2.0))
                .set_titles("{col_name}"))
            g.fig.subplots_adjust(wspace=.05, hspace=0.5)
            g.savefig(os.path.join(output.plot, 'coverage_{}_{}_{}_{}.svg'.format(
                cov_wc.aligner, cov_wc.sequence_workflow, cov_wc.tag, cov_wc.reference)))




rule report:
    input:
        disk_usage = rules.report_disk_usage.output,
        sequences = rules.report_sequences.output,
        coverage = rules.report_alignments_coverage.output
    output:
        pdf = 'report.pdf'
    run:
        import os
        import pandas as pd
        import seaborn as sns

        report = nanopype_report(os.getcwd(), output.pdf)
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
        f_alignments_coverage = [x[0] for x in snakemake.utils.listfiles('report/plots/alignments/coverage/coverage_{tag}.svg')]
        report.add_section_alignments(coverage=f_alignments_coverage)
        # build report pdf
        report.build()
