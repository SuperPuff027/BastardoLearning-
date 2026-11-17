"""Kursordner, die die App beim ersten Start automatisch anlegt.

Jeder Kurs wird ein Ordner, jede Gruppe darin ein Lernset. Quellen:
  * die geprüften Lehrbuch-Listen in diesem Ordner (CSV)
  * die mitgelieferte Vokabeldatenbank, nach Niveau und Thema sortiert
"""
from __future__ import annotations

import csv
import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Version erhöhen, wenn sich Kursinhalte ändern (für spätere Aktualisierungen).
COURSE_VERSION = 1

TAG_LABELS = {
    'alltag': 'Alltag', 'arbeit': 'Arbeit & Beruf', 'einkaufen': 'Einkaufen & Geld',
    'essen': 'Essen & Trinken', 'familie': 'Familie & Menschen', 'farben': 'Farben & Formen',
    'freizeit': 'Freizeit & Hobbys', 'gefuehle': 'Gefühle & Eigenschaften',
    'gesundheit': 'Körper & Gesundheit', 'grammatik': 'Grundwörter & Grammatik',
    'kleidung': 'Kleidung', 'kommunikation': 'Kommunikation', 'natur': 'Natur & Wetter',
    'reisen': 'Reisen & Verkehr', 'schule': 'Schule & Lernen', 'stadt': 'Stadt & Orte',
    'tiere': 'Tiere', 'wohnen': 'Wohnen & Haushalt', 'zahlen': 'Zahlen & Mengen',
    'zeit': 'Zeit & Kalender',
}
MIN_SET = 8  # kleinere Themen landen in „Weitere Wörter“


@dataclass
class Card:
    front: str
    back: str
    vocab_id: int | None = None


@dataclass
class Course:
    key: str
    language: str
    title: str
    subtitle: str
    sets: list[tuple[str, list[Card]]] = field(default_factory=list)


def _front(e) -> str:
    if e.gender == 'mf':
        return f'{e.lemma} (m./f.)'
    return f'{e.article} {e.lemma}' if e.article else e.lemma


def _topic_sets(entries) -> list[tuple[str, list[Card]]]:
    """Ein Set pro Hauptthema (erstes Tag), häufige Wörter zuerst."""
    by_tag: dict[str, list] = defaultdict(list)
    for e in entries:
        by_tag[e.tags[0] if e.tags else ''].append(e)
    big = sorted((t for t in by_tag if t and len(by_tag[t]) >= MIN_SET),
                 key=lambda t: TAG_LABELS.get(t, t))
    rest = [e for t in by_tag if t not in big for e in by_tag[t]]
    out = []
    for t in big + ([''] if rest else []):
        items = by_tag[t] if t else rest
        items = sorted(items, key=lambda e: (e.frequency_rank or 10**9, e.lemma))
        out.append((TAG_LABELS.get(t, 'Weitere Wörter') if t else 'Weitere Wörter',
                    [Card(_front(e), ', '.join(e.translations_de[:3]), e.id) for e in items]))
    return out


def _aula() -> Course:
    rows = list(csv.DictReader(open(HERE / 'es_b1_aula3.csv', encoding='utf-8'), delimiter=';'))
    units: dict[int, list[Card]] = defaultdict(list)
    for r in rows:
        units[int(r['unidad'])].append(Card(r['vorderseite'], r['deutsch']))
    return Course('es_b1_aula3', 'es', 'Spanisch B1 – Aula 3',
                  'Wortschatz aus Aula Internacional Plus 3, nach Unidad',
                  [(f'Unidad {u}', units[u]) for u in sorted(units)])


def _tr_front(head: str, prefix: str) -> str:
    if not prefix:
        return head
    if prefix.startswith('…') or prefix == 'ile':
        return f'{prefix} {head}'
    plus = ['+' + p.replace('(', '').replace(')', '') for p in prefix.split() if p != '…']
    rest = [p for p in prefix.split() if p == '…']
    return ' '.join(rest + [f"({' '.join(plus)})", head])


def _tr_uni() -> Course:
    rows = list(csv.DictReader(open(HERE / 'tr_uni_tuerkisch_1_2.csv', encoding='utf-8'), delimiter=';'))
    groups: dict[str, list[Card]] = {}
    for r in rows:
        front = _tr_front(r['tuerkisch'], r['kasus']) if r['typ'] == 'wort' else r['tuerkisch']
        groups.setdefault(r['gruppe'], []).append(Card(front, r['deutsch']))
    order = lambda g: (0 if g.startswith('Wörter') else 1 if g.startswith('Sätze') else 2)
    names = sorted(groups, key=lambda g: (order(g), list(groups).index(g)))
    return Course('tr_uni_1_2', 'tr', 'Türkisch I + II (Uni)',
                  'Vokabeln aus Türkisch I und II (Uni Duisburg-Essen), A1–A2',
                  [(g, groups[g]) for g in names])


def build_courses(entries_by_lang: dict[str, list]) -> list[Course]:
    es = entries_by_lang.get('es', [])
    tr = entries_by_lang.get('tr', [])
    lvl = lambda es_, *levels: [e for e in es_ if e.cefr_level in levels]
    courses = [_aula(),
               Course('es_a2', 'es', 'Spanisch A2', 'Grundwortschatz A2 nach Thema',
                      _topic_sets(lvl(es, 'A2'))),
               _tr_uni(),
               Course('tr_a1', 'tr', 'Türkisch A1', 'Grundwortschatz A1 nach Thema',
                      _topic_sets(lvl(tr, 'A1'))),
               Course('tr_a2', 'tr', 'Türkisch A2', 'Grundwortschatz A2 nach Thema',
                      _topic_sets(lvl(tr, 'A2'))),
               Course('tr_b1_b2', 'tr', 'Türkisch B1/B2', 'Wortschatz B1 und B2 nach Thema',
                      _topic_sets(lvl(tr, 'B1', 'B2')))]
    return [c for c in courses if c.sets]


SCHEMA = """
    CREATE TABLE course (
        key TEXT PRIMARY KEY,
        language TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        position INTEGER NOT NULL,
        version INTEGER NOT NULL
    );
    CREATE TABLE course_card (
        course_key TEXT NOT NULL REFERENCES course(key),
        set_position INTEGER NOT NULL,
        set_title TEXT NOT NULL,
        position INTEGER NOT NULL,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        vocab_id INTEGER
    );
    CREATE INDEX idx_course_card ON course_card(course_key, set_position, position);
"""


def write_courses(db, courses: list[Course]) -> dict[str, int]:
    db.executescript(SCHEMA)
    counts = {}
    for pos, c in enumerate(courses):
        db.execute('INSERT INTO course VALUES (?,?,?,?,?,?)',
                   (c.key, c.language, c.title, c.subtitle, pos, COURSE_VERSION))
        n = 0
        for sp, (title, cards) in enumerate(c.sets):
            for cp, card in enumerate(cards):
                assert card.front.strip() and card.back.strip(), (c.key, title, card)
                db.execute('INSERT INTO course_card VALUES (?,?,?,?,?,?,?)',
                           (c.key, sp, title, cp, card.front, card.back, card.vocab_id))
                n += 1
        counts[c.key] = n
    return counts
