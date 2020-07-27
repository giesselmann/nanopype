# \HEADER\-------------------------------------------------------------------------
#
#  CONTENTS      : Snakemake nanopore data pipeline
#
#  DESCRIPTION   : pipeline pdf report classes
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
import os, sys
import itertools
import matplotlib.pyplot as plt
from io import BytesIO
from svglib.svglib import svg2rlg
from reportlab.platypus import SimpleDocTemplate, Spacer, PageBreak
from reportlab.platypus import Paragraph, Image, Table
from reportlab.platypus import ListFlowable
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.enums import TA_LEFT,  TA_CENTER, TA_RIGHT
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle




class nanopype_report():
    def __init__(self, cwd, output, version=''):
        self.cwd = cwd
        self.tag = os.path.basename(os.path.normpath(self.cwd))
        self.version = version
        self.story = []
        stylesheet = getSampleStyleSheet()
        self.title_style = stylesheet['Title']
        self.heading_style = stylesheet['Heading2']
        self.heading2_style = stylesheet['Heading3']
        self.normal_style = stylesheet['Normal']
        self.body_style = stylesheet['BodyText']
        self.current_section = 0
        self.doc = doc = SimpleDocTemplate(output,
            pagesize=A4,
            leftMargin=2.2*cm, rightMargin=2.2*cm,
            topMargin=1.5*cm,bottomMargin=2.5*cm)
        self.plot_width = self.doc.width * 0.85
        self.plot_scale = 0.4

    def on_first_page(self, canvas, doc):
        canvas.saveState()
        canvas.rotate(90)
        canvas.setFont('Helvetica-Bold', 100)
        canvas.setFillGray(0.8)
        canvas.drawString(0, -0.95*A4[0], "Nanopype")
        canvas.restoreState()

    def on_later_pages(self, canvas, doc):
        canvas.saveState()
        canvas.setFont('Helvetica', 10)
        canvas.setLineWidth(0.5)
        canvas.line(doc.leftMargin, 1.5*cm, A4[0]-doc.rightMargin, 1.5*cm)
        canvas.drawString(doc.leftMargin, 0.8*cm, "Nanopype report")
        canvas.drawCentredString(A4[0] // 2, 0.8 * cm, "{:d}".format(doc.page))
        canvas.drawRightString(A4[0] - doc.rightMargin, 0.8*cm, "{}".format(self.tag))
        canvas.restoreState()

    def get_section_number(self):
        self.current_section += 1
        return self.current_section

    def add_summary(self, summary_table=[]):
        self.story.append(Spacer(1, 8*cm))
        self.story.append(Paragraph("Sequencing Report", self.title_style))
        style = self.normal_style
        style.alignment = TA_CENTER
        self.story.append(Paragraph("{}".format(self.tag), style))
        self.story.append(Spacer(1, 4*cm))
        summary_table_style = [('ALIGN',(0,0),(0,-1),'RIGHT'),
                               ('ALIGN',(1,0),(1,-1),'LEFT')]
        if len(summary_table):
            self.story.append(Table(summary_table, style=summary_table_style))
        self.story.append(Spacer(1, 1*cm))
        self.story.append(Paragraph("Nanopype {}".format(self.version), style))
        self.story.append(PageBreak())

    def add_section_flowcells(self, runnames=[]):
        self.story.append(Paragraph("{:d} Flow cells".format(self.get_section_number()), self.heading_style))
        self.story.append(Spacer(1, 0))
        table_data = [('{:3d}: '.format(i), runname) for i, runname in enumerate(runnames)]
        table_style = [('FONTSIZE', (0,0), (-1, -1), 10),
                        ('BOTTOMPADDING', (0,0), (-1,-1), 1),
                        ('TOPPADDING', (0,0), (-1,-1), 1),
                        ('VALIGN', (0,0), (-1,-1), 'MIDDLE')]
        self.story.append(Table(table_data, style=table_style))
        self.story.append(Spacer(1, 0.5*cm))

    def add_section_sequences(self, plots=[], stats=None):
        section = self.get_section_number()
        subsection = itertools.count(1)
        plots = sorted(list(plots), key=lambda x : x[1].basecalling)
        if stats is not None:
            self.story.append(Paragraph("{:d} Basecalling".format(section), self.heading_style))
            self.story.append(Spacer(1, 0))
            self.story.append(Paragraph("{:d}.{:d} Summary".format(section, next(subsection)), self.heading2_style))
            #['Tag', 'Basecalling', 'Sum', 'Mean', 'Median', 'N50', 'Maximum']
            header = ['', ''] + list(stats.columns.values[2:])
            table_data = [header] + [[y if isinstance(y, str) else '{:.0f}'.format(y) for y in x] for x in stats.values]
            table_style = [ ('FONTSIZE', (0,0), (-1, -1), 10),
                            ('LINEABOVE', (0,1), (-1,1), 0.5, colors.black),
                            ('LINEBEFORE', (2,0), (2,-1), 0.5, colors.black),
                            ('ALIGN', (0,0), (1,-1), 'LEFT'),
                            ('ALIGN', (2,0), (-1,-1), 'RIGHT')]
            self.story.append(Table(table_data, style=table_style))
            self.story.append(Spacer(1, 0))
        for key, group in itertools.groupby(plots, lambda x : x[1].basecalling):
            self.story.append(Paragraph('{:d}.{:d} {}:'.format(section, next(subsection), key.capitalize()), self.heading2_style))
            for plot_file, plot_wildcards in sorted(list(group), key=lambda x : x[1].i):
                im = svg2rlg(plot_file)
                im = Image(im, width=im.width * self.plot_scale, height=im.height * self.plot_scale)
                im.hAlign = 'CENTER'
                self.story.append(im)
                self.story.append(Spacer(1, 0))
        self.story.append(Spacer(1, 0.5*cm))

    def add_section_alignments(self, counts=[], bases=[], identity=[], coverage=[]):
        section = self.get_section_number()
        subsection = itertools.count(1)
        self.story.append(Paragraph("{:d} Alignments".format(section), self.heading_style))
        self.story.append(Spacer(1, 0))
        if bases:
            self.story.append(Paragraph("{:d}.{:d} Mapped bases (primary alignments)".format(section, next(subsection)), self.heading2_style))
            for b, label in bases:
                im = svg2rlg(b)
                im = Image(im, width=im.width * self.plot_scale, height=im.height * self.plot_scale)
                im.hAlign = 'CENTER'
                self.story.append(Paragraph(label, self.normal_style))
                self.story.append(im)
                self.story.append(Spacer(1, 0))
        if counts:
            self.story.append(Paragraph("{:d}.{:d} Mapped reads".format(section, next(subsection)), self.heading2_style))
            for c, label in counts:
                im = svg2rlg(c)
                im = Image(im, width=im.width * self.plot_scale, height=im.height * self.plot_scale)
                im.hAlign = 'CENTER'
                self.story.append(Paragraph(label, self.normal_style))
                self.story.append(im)
                self.story.append(Spacer(1, 0))
        if identity:
            self.story.append(Paragraph("{:d}.{:d} Read identity (primary alignments, all aligners)".format(section, next(subsection)), self.heading2_style))
            for b, label in identity:
                im = svg2rlg(b)
                im = Image(im, width=im.width * self.plot_scale, height=im.height * self.plot_scale)
                im.hAlign = 'CENTER'
                self.story.append(Paragraph(label, self.normal_style))
                self.story.append(im)
                self.story.append(Spacer(1, 0))
        if coverage:
            self.story.append(Paragraph("{:d}.{:d} Coverage".format(section, next(subsection)), self.heading2_style))
            im = svg2rlg(coverage[0])
            im = Image(im, width=im.width * self.plot_scale, height=im.height * self.plot_scale)
            im.hAlign = 'CENTER'
            self.story.append(im)
            self.story.append(Spacer(1, 0))
        self.story.append(Spacer(1, 0.5*cm))

    def add_section_methylation(self, coverage=[]):
        section = self.get_section_number()
        subsection = itertools.count(1)
        self.story.append(Paragraph("{:d} Methylation".format(section), self.heading_style))
        self.story.append(Spacer(1, 0))
        if coverage:
            self.story.append(Paragraph("{:d}.{:d} CpG coverage".format(section, next(subsection)), self.heading2_style))
            for f, label in coverage:
                im = svg2rlg(f)
                im = Image(im, width=im.width * self.plot_scale, height=im.height * self.plot_scale)
                im.hAlign = 'CENTER'
                self.story.append(Paragraph(label, self.normal_style))
                self.story.append(im)
                self.story.append(Spacer(1, 0))

    def build(self):
        self.doc.build(self.story, onFirstPage=self.on_first_page, onLaterPages=self.on_later_pages)
