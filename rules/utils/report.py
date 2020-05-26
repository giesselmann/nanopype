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







if __name__ == '__main__':
    import matplotlib.pyplot as plt
    from io import BytesIO
    from reportlab.pdfgen import canvas
    from reportlab.graphics import renderPDF
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import cm

    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, PageBreak
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle


    from svglib.svglib import svg2rlg

    fig = plt.figure(figsize=(4, 3))
    plt.plot([1,2,3,4])
    plt.ylabel('some numbers')

    imgdata = BytesIO()
    fig.savefig(imgdata, format='svg')
    imgdata.seek(0)  # rewind the data
    drawing=svg2rlg(imgdata)

    Story = []
    Story.append(Spacer(1, 12))
    Story.append(Image(drawing))

    doc = SimpleDocTemplate("test.pdf")
    doc.build(Story)


    c = canvas.Canvas('test2.pdf', pagesize=A4)
    c.translate(cm,cm)
    renderPDF.draw(drawing, c, 10, 40)
    c.showPage()
    c.translate(cm,cm)
    c.drawString(0, 0, "So nice it works")
    c.showPage()
    c.save()
