"""Wandelt kompakte Seed-Dateien (seed/<lang>_*.txt) in data/<lang>.jsonl um.

Zeilenformat (Trennzeichen „|“, Listen mit „;“ bzw. „,“):
    lemma|pos|gender|cefr|übersetzungen;…|beispiel|beispiel_de|formen,…|tags,…

Leere Zeilen und Zeilen mit „#“ am Anfang werden ignoriert.
Die ersten 1.000 Einträge pro Sprache wurden so direkt mit Claude im
Entwicklungs-Chat erzeugt; Erweiterungen laufen über generate.py.
"""

from __future__ import annotations

import sys
from pathlib import Path

from vocab_schema import Entry

ROOT = Path(__file__).parent


def parse_line(line: str, lang: str) -> Entry:
    parts = line.rstrip("\n").split("|")
    if len(parts) != 9:
        raise ValueError(f"{len(parts)} statt 9 Felder: {line!r}")
    lemma, pos, gender, cefr, tr, ex, ex_de, forms, tags = (p.strip() for p in parts)
    split = lambda s, sep: [x.strip() for x in s.split(sep) if x.strip()]
    return Entry(
        lemma=lemma,
        language=lang,
        pos=pos,
        gender=gender or None,
        cefr_level=cefr,
        translations_de=split(tr, ";"),
        example_sentence=ex,
        example_translation=ex_de,
        forms=split(forms, ","),
        tags=split(tags, ","),
    )


def load_seed(lang: str) -> list[Entry]:
    entries: list[Entry] = []
    for path in sorted((ROOT / "seed").glob(f"{lang}_*.txt")):
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            try:
                entries.append(parse_line(line, lang))
            except ValueError as e:
                raise SystemExit(f"{path.name}:{no}: {e}")
    return entries


def main(langs: list[str]) -> None:
    for lang in langs:
        entries = load_seed(lang)
        out = ROOT / "data" / f"{lang}.jsonl"
        out.write_text("".join(e.to_json() + "\n" for e in entries), encoding="utf-8")
        print(f"{lang}: {len(entries)} Einträge → {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:] or ["es", "tr"])
