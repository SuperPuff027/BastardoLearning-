"""Automatische Plausibilitätsprüfung (Brief Abschnitt 5, Schritt 3).

Setzt `issues` und `verified` für jeden Eintrag in data/<lang>.jsonl und
ergänzt `frequency_rank` aus der Häufigkeitsliste. Einträge mit Problemen
bleiben in der Datenbank, werden in der App aber als „unbestätigt“ markiert.
Ein Lauf von `generate.py review` kann zusätzliche Probleme eintragen
(issues mit Präfix „review:“); diese bleiben erhalten.
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

import frequency
from vocab_schema import CEFR, POS, TAGS, Entry, fold, normalize

ROOT = Path(__file__).parent
DE_ARTICLES = ("der ", "die ", "das ")


def check(e: Entry, duplicates: set[tuple[str, str]]) -> list[str]:
    issues: list[str] = []
    if not e.lemma.strip():
        issues.append("Lemma leer")
    if e.pos not in POS:
        issues.append(f"Unbekannte Wortart {e.pos!r}")
    if e.cefr_level not in CEFR:
        issues.append(f"Unbekanntes Niveau {e.cefr_level!r}")
    if not e.translations_de or any(not t.strip() for t in e.translations_de):
        issues.append("Übersetzung fehlt")
    unknown_tags = [t for t in e.tags if t not in TAGS]
    if unknown_tags:
        issues.append(f"Unbekannte Themen {unknown_tags}")
    if not e.tags:
        issues.append("Kein Thema")
    if e.language == "es" and e.pos == "noun" and e.gender not in ("m", "f", "mf"):
        issues.append("Genus fehlt")
    if e.gender and not (e.language == "es" and e.pos == "noun"):
        issues.append("Genus nur bei spanischen Nomen")
    if e.pos == "noun" and e.translations_de:
        main = e.translations_de[0]
        if not main.lower().startswith(DE_ARTICLES):
            issues.append("Deutsche Hauptübersetzung ohne Artikel")
    if not e.example_sentence or not e.example_translation:
        issues.append("Beispielsatz fehlt")
    else:
        sentence = fold(e.example_sentence)
        words = [e.lemma, *e.forms]
        # Mehrwort-Lemmas und Türkisch (Suffixe): Teilstring-Prüfung genügt
        if not any(fold(w) and fold(w) in sentence for w in words):
            issues.append("Beispielsatz enthält weder Lemma noch eine Form")
    if (normalize(e.lemma), e.pos) in duplicates:
        issues.append("Doppelter Eintrag")
    return issues


def run(lang: str) -> tuple[int, int]:
    path = ROOT / "data" / f"{lang}.jsonl"
    entries = [Entry.from_dict(__import__("json").loads(l))
               for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]
    counts = Counter((normalize(e.lemma), e.pos) for e in entries)
    duplicates = {k for k, n in counts.items() if n > 1}
    table = frequency.ranks(lang)
    bad = 0
    for e in entries:
        review = [i for i in e.issues if i.startswith("review:")]
        e.issues = check(e, duplicates) + review
        e.verified = not e.issues
        e.frequency_rank = frequency.rank_of(e.lemma, e.forms, table)
        bad += not e.verified
    path.write_text("".join(e.to_json() + "\n" for e in entries), encoding="utf-8")
    return len(entries), bad


def main(langs: list[str]) -> None:
    for lang in langs:
        total, bad = run(lang)
        print(f"{lang}: {total} Einträge, {total - bad} geprüft ok, {bad} unbestätigt")


if __name__ == "__main__":
    main(sys.argv[1:] or ["es", "tr"])
