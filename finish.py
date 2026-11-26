import html
import io
import json
import re
import sys
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import quote, unquote
from pypdf import PdfReader, PdfWriter
from pypdf.generic import Fit
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm

mode, source, *args = sys.argv[1:]
path = Path(source)
text = path.read_text()
nav = re.compile(r'(<nav id="TOC"[^>]*>)(.*?)(</nav>)', re.S)
links = re.compile(r'(<a\b[^>]*href="#[^"]+"[^>]*>)(.*?)(</a>)', re.S)

section_heading = re.compile(r'(<section\b[^>]*\bid="([^"]+)"[^>]*>\s*<h[1-6]\b[^>]*>)', re.I)
heading = re.compile(r'(<h[1-6]\b[^>]*\bid="([^"]+)"[^>]*>)', re.I)
marker = re.compile(r'<a class="md2pdf-probe" href="https://md2pdf.invalid/dest/[^"]+">&#x2022;</a>')

def key(value):
    return unquote(html.unescape(value)).lstrip('#')

class DocumentInfo(HTMLParser):
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.headings = []
        self.meta = {}
        self.current = None
        self.in_article = False
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'article' and 'markdown-body' in attrs.get('class', '').split():
            self.in_article = True
        if tag == 'meta' and attrs.get('name') in ('author', 'subject', 'keywords'):
            self.meta.setdefault(attrs['name'], []).append(attrs.get('content', ''))
        if self.in_article and re.fullmatch(r'h[1-6]', tag):
            self.current = [int(tag[1]), attrs.get('id'), []]

    def handle_data(self, data):
        if self.current:
            self.current[2].append(data)

    def handle_endtag(self, tag):
        if self.current and tag == f'h{self.current[0]}':
            level, ident, chunks = self.current
            if ident:
                self.headings.append((level, key(ident), ' '.join(''.join(chunks).split())))
            self.current = None
        if tag == 'article':
            self.in_article = False


def destinations(reader):
    result = {}
    for name, dest in reader.named_destinations.items():
        number = reader.get_destination_page_number(dest)
        if number >= 0:
            result[key(name)] = [number, float(dest.top) if dest.top is not None else None]
    for number, page in enumerate(reader.pages):
        for ref in page.get('/Annots', []):
            annotation = ref.get_object()
            action = annotation.get('/A')
            if action is None:
                continue
            uri = str(action.get_object().get('/URI', ''))
            prefix = 'https://md2pdf.invalid/dest/'
            if uri.startswith(prefix):
                rect = annotation.get('/Rect')
                result[unquote(uri[len(prefix):])] = [number, float(rect[3]) if rect else None]
    return result


if mode == 'prepare':
    def prepare(m):
        def entry(a):
            return a[1] + '<span class="toc-label">' + a[2] + '</span><span class="toc-leader"></span><span class="toc-page">&nbsp;</span>' + a[3]
        return m[1] + links.sub(entry, m[2]) + m[3]
    text = nav.sub(prepare, text)
    def probe(m):
        return m[1] + '<a class="md2pdf-probe" href="https://md2pdf.invalid/dest/' + quote(key(m[2]), safe='') + '">&#x2022;</a>'
    text = heading.sub(probe, text)
    text = section_heading.sub(probe, text)
    path.write_text(text)
elif mode == 'contents':
    reader = PdfReader(args[0])
    found = destinations(reader)
    path.with_suffix('.destinations.json').write_text(json.dumps(found))
    by_id = {ident: value[0] + 1 for ident, value in found.items()}
    missing = []
    def populate(m):
        def entry(a):
            ident = key(re.search(r'href="#([^"]+)"', a[1])[1])
            page = by_id.get(ident)
            if page is None:
                missing.append(ident)
                return a[1] + a[2].replace('<span class="toc-leader"></span><span class="toc-page">&nbsp;</span>', '') + a[3]
            return a[1] + a[2].replace('&nbsp;</span>', str(page) + '</span>') + a[3]
        return m[1] + links.sub(entry, m[2]) + m[3]
    updated = marker.sub('', nav.sub(populate, text))
    if missing:
        print('md2pdf: unresolved TOC destinations: ' + ', '.join(missing), file=sys.stderr)
    if updated == text:
        sys.exit(1)
    path.write_text(updated)
elif mode == 'finish':
    original, output, footer = args
    reader = PdfReader(original)
    writer = PdfWriter(clone_from=reader)
    title = re.search(r'<title>(.*?)</title>', text, re.S)
    title = html.unescape(re.sub(r'<[^>]+>', '', title[1])) if title else 'Document'
    info = DocumentInfo(text)
    metadata = {'/Title': title}
    for name, values in info.meta.items():
        metadata['/' + name.capitalize()] = ', '.join(values)
    writer.add_metadata(metadata)
    saved = path.with_suffix('.destinations.json')
    resolved = json.loads(saved.read_text()) if saved.exists() else {}
    resolved.update(destinations(reader))
    # Replace any browser-generated outline with a consistent heading hierarchy.
    if info.headings:
        from pypdf.generic import NameObject
        writer.root_object.pop(NameObject('/Outlines'), None)
        parents = []
        for level, ident, label in info.headings:
            target = resolved.get(ident)
            if not target or not label or not 0 <= target[0] < len(writer.pages):
                continue
            while parents and parents[-1][0] >= level:
                parents.pop()
            parent = parents[-1][1] if parents else None
            item = writer.add_outline_item(label, target[0], parent=parent,
                                           fit=Fit.fit_horizontally(target[1]))
            parents.append((level, item))
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
