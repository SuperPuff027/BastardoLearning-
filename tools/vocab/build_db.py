"""Baut assets/vocab/vocab.db (SQLite, schreibgeschützt in der App).

Tabellen:
  meta          key/value (schema_version, data_version, Lizenzhinweis)
  vocab         ein Eintrag pro Lemma
  vocab_form    Suchschlüssel Fremdsprache: Lemma, Artikel+Lemma, Formen
  vocab_de      Suchschlüssel Deutsch: Übersetzungen ohne Artikel

Vergibt fehlende stabile IDs und schreibt sie nach data/<lang>.jsonl zurück.
"""

from __future__ import annotations

import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

from vocab_schema import ID_BASE, Entry, fold, normalize

ROOT = Path(__file__).parent
OUT = ROOT.parent.parent / "assets" / "vocab" / "vocab.db"
SCHEMA_VERSION = 1

ATTRIBUTION = (
    "Häufigkeitsdaten: FrequencyWords von Hermit Dave (OpenSubtitles 2018), "
    "CC BY-SA 4.0, https://github.com/hermitdave/FrequencyWords. "
    "Übersetzungen, Beispielsätze und Einordnung: KI-generiert (Claude, Anthropic), "
    "automatisch geprüft; Fehler sind möglich."
)

DE_ARTICLES = ("der ", "die ", "das ", "den ", "dem ", "ein ", "eine ")


def strip_de_article(t: str) -> str:
    n = normalize(t)
    for a in DE_ARTICLES:
        if n.startswith(a):
            return n[len(a):]
    return n


def load(lang: str) -> list[Entry]:
    path = ROOT / "data" / f"{lang}.jsonl"
    if not path.exists():
        return []
    return [Entry.from_dict(json.loads(l))
            for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def assign_ids(lang: str, entries: list[Entry]) -> None:
    used = [e.id for e in entries if e.id is not None]
    next_id = max(used, default=ID_BASE[lang]) + 1
    for e in entries:
        if e.id is None:
            e.id = next_id
            next_id += 1
    path = ROOT / "data" / f"{lang}.jsonl"
    path.write_text("".join(e.to_json() + "\n" for e in entries), encoding="utf-8")


def build(langs: list[str], out: Path = OUT) -> dict[str, int]:
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    db = sqlite3.connect(out)
    db.executescript("""
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE vocab (
            id INTEGER PRIMARY KEY,
            language TEXT NOT NULL,
            lemma TEXT NOT NULL,
            pos TEXT NOT NULL,
            gender TEXT,
            article TEXT,
            cefr_level TEXT NOT NULL,
            frequency_rank INTEGER,
            translations_de TEXT NOT NULL,
            example_sentence TEXT NOT NULL,
            example_translation TEXT NOT NULL,
            forms TEXT NOT NULL,
            tags TEXT NOT NULL,
            verified INTEGER NOT NULL
        );
        CREATE TABLE vocab_form (
            language TEXT NOT NULL,
            form TEXT NOT NULL,
            form_folded TEXT NOT NULL,
            vocab_id INTEGER NOT NULL REFERENCES vocab(id),
            is_lemma INTEGER NOT NULL
        );
        CREATE TABLE vocab_de (
            language TEXT NOT NULL,
            de TEXT NOT NULL,
            de_folded TEXT NOT NULL,
            vocab_id INTEGER NOT NULL REFERENCES vocab(id),
            position INTEGER NOT NULL
        );
        CREATE INDEX idx_vocab_lang_rank ON vocab(language, frequency_rank);
        CREATE INDEX idx_form ON vocab_form(language, form);
        CREATE INDEX idx_form_folded ON vocab_form(language, form_folded);
        CREATE INDEX idx_de ON vocab_de(language, de);
        CREATE INDEX idx_de_folded ON vocab_de(language, de_folded);
    """)
    counts: dict[str, int] = {}
    for lang in langs:
        entries = load(lang)
        assign_ids(lang, entries)
        counts[lang] = len(entries)
        for e in entries:
            db.execute(
                "INSERT INTO vocab VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (e.id, lang, e.lemma, e.pos, e.gender, e.article, e.cefr_level,
                 e.frequency_rank, json.dumps(e.translations_de, ensure_ascii=False),
                 e.example_sentence, e.example_translation,
                 json.dumps(e.forms, ensure_ascii=False),
                 json.dumps(e.tags, ensure_ascii=False), int(e.verified)))
            keys = {normalize(e.lemma): 1}
            if e.article:
                keys.setdefault(normalize(f"{e.article} {e.lemma}"), 1)
            for f in e.forms:
                keys.setdefault(normalize(f), 0)
            for k, is_lemma in keys.items():
                db.execute("INSERT INTO vocab_form VALUES (?,?,?,?,?)",
                           (lang, k, fold(k), e.id, is_lemma))
            seen_de: set[str] = set()
            for pos, t in enumerate(e.translations_de):
                k = strip_de_article(t)
                if k and k not in seen_de:
                    seen_de.add(k)
                    db.execute("INSERT INTO vocab_de VALUES (?,?,?,?,?)",
                               (lang, k, fold(k), e.id, pos))
    meta = {
        "schema_version": str(SCHEMA_VERSION),
        "data_version": dt.date.today().isoformat(),
        "attribution": ATTRIBUTION,
        **{f"count_{l}": str(n) for l, n in counts.items()},
    }
    db.executemany("INSERT INTO meta VALUES (?,?)", meta.items())
    db.commit()
    db.execute("VACUUM")
    db.close()
    return counts


def main(langs: list[str]) -> None:
    counts = build(langs)
    size = OUT.stat().st_size / 1024
    print(f"{OUT.relative_to(ROOT.parent.parent)}: {counts}, {size:.0f} KB")


if __name__ == "__main__":
    main(sys.argv[1:] or ["es", "tr"])
