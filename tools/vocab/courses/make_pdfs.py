"""Erzeugt die Vokabel-PDFs in docs/vokabeln/ aus den geprüften Kursdateien.

    python3 tools/vocab/courses/make_pdfs.py
"""
import csv
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, KeepTogether
from xml.sax.saxutils import escape

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'docs' / 'vokabeln'
FONT_DIR = Path('/usr/share/fonts/truetype/liberation')
pdfmetrics.registerFont(TTFont('Sans', FONT_DIR / 'LiberationSans-Regular.ttf'))
pdfmetrics.registerFont(TTFont('Sans-Bold', FONT_DIR / 'LiberationSans-Bold.ttf'))
pdfmetrics.registerFont(TTFont('Sans-Oblique', FONT_DIR / 'LiberationSans-Italic.ttf'))
pdfmetrics.registerFontFamily('Sans', normal='Sans', bold='Sans-Bold', italic='Sans-Oblique')

H1 = ParagraphStyle('h1', fontName='Sans-Bold', fontSize=16, leading=20, spaceAfter=4)
NOTE = ParagraphStyle('note', fontName='Sans', fontSize=8, leading=10, textColor=colors.grey, spaceAfter=8)
H2 = ParagraphStyle('h2', fontName='Sans-Bold', fontSize=12, leading=15, spaceBefore=10, spaceAfter=4,
                    textColor=colors.HexColor('#1f5fa8'))
ENTRY = ParagraphStyle('entry', fontName='Sans', fontSize=9.5, leading=12.5, leftIndent=10, firstLineIndent=-10,
                       spaceAfter=1.5)
EX = ParagraphStyle('ex', parent=ENTRY, leftIndent=26, firstLineIndent=-10, fontSize=8.8, leading=11.5,
                    textColor=colors.HexColor('#333333'))


def footer(title):
    def draw(canvas, doc):
        canvas.saveState()
        canvas.setFont('Sans', 7.5)
        canvas.setFillColor(colors.grey)
        canvas.drawString(18 * mm, 10 * mm, title)
        canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f'Seite {doc.page}')
        canvas.restoreState()
    return draw


def build(path, title, flow):
    doc = SimpleDocTemplate(str(path), pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=16 * mm, bottomMargin=18 * mm, title=title, author='Barstardo Learning')
    doc.build(flow, onFirstPage=footer(title), onLaterPages=footer(title))


def e(s):
    return escape(s)


ES_ORDER = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ'
TR_ORDER = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ'
PLAIN = str.maketrans('ÁÉÍÓÚ', 'AEIOU')


def initial(word, order):
    """Anfangsbuchstabe für die Zwischenüberschrift (ohne ¡¿(…) und Klammerzusätze)."""
    w = re.sub(r'^[\s¡¿…]*(\([^)]*\)\s*)?', '', word)
    if not w:
        return None
    c = w[0]
    c = 'İ' if c == 'i' else c.upper().translate(PLAIN)
    return c if c in order else None


def advance(current, letter, order):
    """Neue Überschrift nur, wenn der Buchstabe im Alphabet weiter hinten liegt."""
    if letter is None:
        return False
    return current is None or order.index(letter) > order.index(current)


def aula():
    rows = list(csv.DictReader(open(HERE / 'es_b1_aula3.csv', encoding='utf-8'), delimiter=';'))
    title = 'Aula Internacional Plus 3 (B1) – Wortschatz Spanisch–Deutsch'
    flow = [Paragraph(e(title), H1),
            Paragraph(f'{len(rows)} Einträge in der Reihenfolge des Buchs (A–Z). '
                      'Angabe rechts: Einheit_Abschnitt, z. B. U3_2D = Unidad 3, Abschnitt 2D. '
                      'm/f = Genus, pl = Plural.', NOTE)]
    letter = None
    for r in rows:
        first = initial(r['spanisch'], ES_ORDER)
        if advance(letter, first, ES_ORDER):
            letter = first
            flow.append(Paragraph(e(letter), H2))
        genus = f' <font color="#888888" size="8">{e(r["genus"])}</font>' if r['genus'] else ''
        flow.append(Paragraph(
            f'<b>{e(r["spanisch"])}</b>{genus} – {e(r["deutsch"])}'
            f' <font color="#888888" size="7.5">{e(r["abschnitt"])}</font>', ENTRY))
    build(OUT / 'Aula-Internacional-Plus-3_Wortschatz_B1.pdf', title, flow)
    return rows


def tuerkisch():
    rows = list(csv.DictReader(open(HERE / 'tr_uni_tuerkisch_1_2.csv', encoding='utf-8'), delimiter=';'))
    title = 'Türkisch I und II – Vokabeln Türkisch–Deutsch'
    words = sum(r['typ'] == 'wort' for r in rows)
    sents = sum(r['typ'] == 'satz' for r in rows)
    flow = [Paragraph(e(title), H1),
            Paragraph(f'{words} Stichwörter mit {sents} Beispielsätzen und {len(rows) - words - sents} '
                      'Wörter aus den Wortfeldern im Anhang. In eckigen Klammern: verlangter Kasus '
                      '(z. B. İ = Akkusativ, E = Dativ).', NOTE)]
    head = None
    letter = None
    block = []
    def flush():
        if block:
            flow.append(KeepTogether(list(block)))
            block.clear()
    for r in rows:
        if r['typ'] == 'satz':
            block.append(Paragraph(f'<i>{e(r["tuerkisch"])}</i> – {e(r["deutsch"])}', EX))
            continue
        flush()
        heading = head
        if r['typ'] == 'wortfeld':
            heading = r['gruppe']
        else:
            first = initial(r['tuerkisch'], TR_ORDER)
            if advance(letter, first, TR_ORDER):
                letter = first
                heading = f'Buchstabe {letter}'
        if heading != head:
            head = heading
            flow.append(Paragraph(e(heading), H2))
        kasus = f' <font color="#888888" size="8">[{e(r["kasus"])}]</font>' if r['kasus'] else ''
        block.append(Paragraph(f'<b>{e(r["tuerkisch"])}</b>{kasus} – {e(r["deutsch"])}', ENTRY))
    flush()
    build(OUT / 'Tuerkisch-I-und-II_Vokabeln.pdf', title, flow)
    return rows


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    print('Aula:', len(aula()))
    print('Türkisch:', len(tuerkisch()))
