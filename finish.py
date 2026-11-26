import html
import io
import re
import sys
from pathlib import Path
from urllib.parse import unquote
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm

mode, source, *args = sys.argv[1:]
path = Path(source)
text = path.read_text()
nav = re.compile(r'(<nav id="TOC"[^>]*>)(.*?)(</nav>)', re.S)
links = re.compile(r'(<a\b[^>]*href="#[^"]+"[^>]*>)(.*?)(</a>)', re.S)

if mode == 'prepare':
    def prepare(m):
        return m[1] + links.sub(lambda a: a[1] + a[2] + '<span class="toc-leader"></span><span class="toc-page">&nbsp;</span>' + a[3], m[2]) + m[3]
    path.write_text(nav.sub(prepare, text))
elif mode == 'contents':
    reader = PdfReader(args[0])
    destinations = reader.named_destinations
    by_id = {}
    for name, dest in destinations.items():
        number = reader.get_destination_page_number(dest)
        if number >= 0:
            by_id[unquote(name).lstrip('#')] = number + 1
    def populate(m):
        def entry(a):
            key = unquote(html.unescape(re.search(r'href="#([^"]+)"', a[1])[1]))
            page = by_id.get(key)
            if page is None:
                return a[1] + a[2].replace('<span class="toc-leader"></span><span class="toc-page">&nbsp;</span>', '') + a[3]
            return a[1] + a[2].replace('&nbsp;</span>', str(page) + '</span>') + a[3]
        return m[1] + links.sub(entry, m[2]) + m[3]
    updated = nav.sub(populate, text)
    if updated == text:
        sys.exit(1)
    if not by_id:
        print('md2pdf: Chromium provided no named destinations; TOC page numbers omitted', file=sys.stderr)
    path.write_text(updated)
elif mode == 'finish':
    original, output, footer = args
    reader = PdfReader(original)
    writer = PdfWriter(clone_from=reader)
    title = re.search(r'<title>(.*?)</title>', text, re.S)
    title = html.unescape(re.sub(r'<[^>]+>', '', title[1])) if title else 'Document'
    cover = 'data-cover="yes"' in text
    if footer == 'true':
        for i, page in enumerate(writer.pages):
            if cover and i == 0:
                continue
            width, height = float(page.mediabox.width), float(page.mediabox.height)
            buffer = io.BytesIO()
            c = canvas.Canvas(buffer, pagesize=(width, height))
            c.setStrokeColorRGB(.85, .88, .91)
            c.setFillColorRGB(.32, .39, .48)
            c.setLineWidth(.4)
            c.line(18*mm, 13*mm, width-18*mm, 13*mm)
            c.setFont('Helvetica', 8)
            label = title
            while label and c.stringWidth(label, 'Helvetica', 8) > width - 65*mm:
                label = label[:-1]
            c.drawString(18*mm, 8*mm, label)
            c.drawRightString(width-18*mm, 8*mm, f'{i+1} / {len(writer.pages)}')
            c.save()
            buffer.seek(0)
            page.merge_page(PdfReader(buffer).pages[0])
    writer.write(output)
