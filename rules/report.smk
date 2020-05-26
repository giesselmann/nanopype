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




rule report_disk_usage:
    input:
        runs = lambda wildcards : [os.path.join(config['storage_data_raw'], runname) for runname in config['runnames']],
        modules = lambda wildcards : [m for m in
            ['sequences', 'alignments', 'methylation', 'sv', 'transcript', 'assembly']
            if os.path.isdir(m)]
    output:
        temp('report/stats/disk_usage.hdf5')
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
        lambda wildcards : [x[0] for x in snakemake.utils.listfiles('sequences/{sequence_workflow, ((?!batches).)*}/batches/{tag, [^\/]*}')]
    output:
        directory('report/stats/sequences'),
        directory('report/plots/sequences')
    run:
        import os
        




checkpoint report_coverage_plot:
    input:
        ''
    output:
        ''
    params:
        bin_width = 500000
    run:
        import re
        import pandas as pd
        import seaborn as sns
        from matplotlib import pyplot as plt

        cov_file = 'alignments/ngmlr/guppy/Hues8.fast.hg38.bedGraph'
        df = pd.read_csv(cov_file, sep='\t', header=None, names=['chr', 'begin', 'end', 'coverage'])

        df['bin'] = df['begin'] // params.bin_width

        def sort_key(k):
            return ''.join(re.findall(r'\D+', k) + ['{:05d}'.format(int(m)) for m in re.findall(r'\d+', k)])

        df_agg = df.groupby(['chr', 'bin']).agg(
            begin=('begin', 'first'),
            end=('end', 'last'),
            coverage=('coverage', 'median')
        ).reset_index()

        df_agg['key'] = df_agg.chr.map(sort_key)
        df_agg = df_agg.sort_values(by=['key', 'begin']).drop(columns=['key'])

        g = sns.FacetGrid(df_agg, col="chr", hue='chr', col_wrap=4, sharex=True, height=1, aspect=3)
        g = (g.map(plt.plot, "begin", "coverage", marker=".", lw=0, markersize=0.2)
            .set(ylim=(0, df_agg.coverage.mean() * 1.5))
            .set_titles("{col_name}"))
        g.fig.subplots_adjust(wspace=.05, hspace=0.5)
        g.savefig('coverage.svg')




rule report:
    input:
    output:
        'report.pdf'
    run:
        pass
