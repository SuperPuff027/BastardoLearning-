"""Häufigkeitslisten (FrequencyWords, OpenSubtitles 2018).

Quelle: https://github.com/hermitdave/FrequencyWords
Lizenz des Inhalts: CC BY-SA 4.0 (Hermit Dave) – Namensnennung in der App.
"""

from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

from vocab_schema import normalize

DATA = Path(__file__).parent / "data"
URL = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/{lang}/{lang}_50k.txt"


def path_for(lang: str) -> Path:
    return DATA / f"freq_{lang}.txt"


def download(lang: str) -> Path:
    p = path_for(lang)
    if not p.exists():
        DATA.mkdir(exist_ok=True)
        print(f"Lade Häufigkeitsliste {lang} …", file=sys.stderr)
        urllib.request.urlretrieve(URL.format(lang=lang), p)
    return p


def ranks(lang: str) -> dict[str, int]:
    """Wortform → Rang (1 = häufigstes Wort)."""
    out: dict[str, int] = {}
    with download(lang).open(encoding="utf-8") as f:
        for i, line in enumerate(f, start=1):
            word = line.split(" ", 1)[0]
            out.setdefault(normalize(word), i)
    return out


def top_words(lang: str, n: int) -> list[str]:
    words = []
    with download(lang).open(encoding="utf-8") as f:
        for line in f:
            w = normalize(line.split(" ", 1)[0])
            if w.isalpha():
                words.append(w)
            if len(words) >= n:
                break
    return words


def rank_of(lemma: str, forms: list[str], table: dict[str, int]) -> int | None:
    """Bester Rang aus Lemma und Formen (Untertitel enthalten Beugungsformen)."""
    candidates = [lemma, *forms]
    found = [table[normalize(c)] for c in candidates if normalize(c) in table]
    return min(found) if found else None
