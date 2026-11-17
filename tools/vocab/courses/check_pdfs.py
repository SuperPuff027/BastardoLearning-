"""Prüft die erzeugten PDFs gegen die Kursdateien (Rundreise PDF → Text → Vergleich).

Jeder Eintrag muss vollständig, zeichengenau und in der richtigen Reihenfolge im
PDF-Text stehen; außerdem darf das PDF keinen Vokabeltext enthalten, der nicht
aus den Kursdateien stammt.
"""
import csv, re, sys
from pathlib import Path
import pdfplumber

HERE = Path(__file__).resolve().parent
DOCS = HERE.parents[2] / 'docs' / 'vokabeln'
ws = lambda s: re.sub(r'\s+', '', s)

def pdf_text(name):
    with pdfplumber.open(DOCS / name) as pdf:
        return '\n'.join(p.extract_text() or '' for p in pdf.pages)

def check(name, pieces, extra_patterns):
    text = pdf_text(name)
    flat = ws(text)
    pos, missing = 0, []
    spans = []
    for label, piece in pieces:
        p = ws(piece)
        i = flat.find(p, pos)
        if i < 0:
            missing.append(label)
            continue
        spans.append((i, i + len(p)))
        pos = i + len(p)
    # Rest = alles, was nicht zu einem Eintrag gehört (Überschriften, Fußzeilen)
    rest, last = [], 0
    for a, b in spans:
        rest.append(flat[last:a]); last = b
    rest.append(flat[last:])
    leftover = ''.join(rest)
    for pat in extra_patterns:
        leftover = re.sub(pat, '', leftover)
    print(f'{name}: {len(pieces)} Einträge, gefunden {len(pieces) - len(missing)}, fehlend {len(missing)}')
    for m in missing[:20]:
        print('  FEHLT:', m)
    print(f'  übrig gebliebener Text (sollte leer sein): {leftover[:200]!r}')
    return not missing and not leftover

ok = True
aula = list(csv.DictReader(open(HERE / 'es_b1_aula3.csv', encoding='utf-8'), delimiter=';'))
ok &= check('Aula-Internacional-Plus-3_Wortschatz_B1.pdf',
            [(r['nr'], f"{r['spanisch']} {r['genus']} – {r['deutsch']} {r['abschnitt']}") for r in aula],
            [r'AulaInternacionalPlus3\(B1\)–WortschatzSpanisch–Deutsch', r'Seite\d+',
             r'2079EinträgeinderReihenfolgedesBuchs.*?pl=Plural\.', r'^ABCDEFGHIJLMNOPQRSTUVWXYZ$'])
tr = list(csv.DictReader(open(HERE / 'tr_uni_tuerkisch_1_2.csv', encoding='utf-8'), delimiter=';'))
ok &= check('Tuerkisch-I-und-II_Vokabeln.pdf',
            [(r['nr'], f"{r['tuerkisch']} {'[' + r['kasus'] + ']' if r['kasus'] else ''} – {r['deutsch']}") for r in tr],
            [r'TürkischIundII–VokabelnTürkisch–Deutsch', r'Seite\d+',
             r'806Stichwörter.*?E=Dativ\)\.', r'Buchstabe[A-ZÇÖŞÜİ]'] + [re.escape(ws(g)) for g in sorted({r['gruppe'] for r in tr if r['typ'] == 'wortfeld'}, key=len, reverse=True)])
print('ERGEBNIS:', 'OK' if ok else 'FEHLER')
sys.exit(0 if ok else 1)
