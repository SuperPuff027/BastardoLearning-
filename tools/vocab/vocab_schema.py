"""Gemeinsames Schema der Vokabeldatenbank (Brief Abschnitt 5)."""

from __future__ import annotations

import json
import unicodedata
from dataclasses import asdict, dataclass, field

LANGUAGES = ("es", "tr")

POS = (
    "noun", "verb", "adj", "adv", "pron", "prep", "conj", "det", "num",
    "interj", "phrase",
)
CEFR = ("A1", "A2", "B1", "B2", "C1", "C2")

# Themen für vorgefertigte Sets (Schlüssel → deutscher Name)
TAGS = {
    "alltag": "Alltag",
    "arbeit": "Arbeit & Beruf",
    "einkaufen": "Einkaufen & Geld",
    "essen": "Essen & Trinken",
    "familie": "Familie & Menschen",
    "farben": "Farben & Formen",
    "freizeit": "Freizeit & Hobbys",
    "gefuehle": "Gefühle & Eigenschaften",
    "gesundheit": "Körper & Gesundheit",
    "grammatik": "Grundwörter & Grammatik",
    "kleidung": "Kleidung",
    "kommunikation": "Kommunikation",
    "natur": "Natur & Wetter",
    "reisen": "Reisen & Verkehr",
    "schule": "Schule & Lernen",
    "stadt": "Stadt & Orte",
    "tiere": "Tiere",
    "wohnen": "Wohnen & Haushalt",
    "zahlen": "Zahlen & Mengen",
    "zeit": "Zeit & Kalender",
}

ARTICLES_ES = {"m": "el", "f": "la"}

# ID-Bereiche pro Sprache
ID_BASE = {"es": 1_000_000, "tr": 2_000_000}


@dataclass
class Entry:
    lemma: str
    language: str
    pos: str
    cefr_level: str
    translations_de: list[str]
    example_sentence: str = ""
    example_translation: str = ""
    forms: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    gender: str | None = None  # nur es: m, f, mf
    frequency_rank: int | None = None
    verified: bool = False
    issues: list[str] = field(default_factory=list)
    # Stabile ID: Karten in der App verweisen darauf (vocab_id). Wird beim
    # ersten Build vergeben und danach nie mehr geändert.
    id: int | None = None

    @property
    def article(self) -> str | None:
        if self.language != "es" or self.pos != "noun" or not self.gender:
            return None
        return ARTICLES_ES.get(self.gender[0])

    def to_json(self) -> str:
        return json.dumps(asdict(self), ensure_ascii=False)

    @staticmethod
    def from_dict(d: dict) -> "Entry":
        known = {f for f in Entry.__dataclass_fields__}
        return Entry(**{k: v for k, v in d.items() if k in known})


def normalize(text: str) -> str:
    """Kleinbuchstaben, ohne Satzzeichen am Rand (wie in der App)."""
    t = text.replace("İ", "i").lower().strip()
    return t.strip(" .,;:!?¡¿\"'«»„“”")


_FOLD = str.maketrans({
    "á": "a", "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e",
    "í": "i", "ì": "i", "î": "i", "ï": "i", "ı": "i", "ó": "o", "ò": "o",
    "ô": "o", "ö": "o", "ú": "u", "ù": "u", "û": "u", "ü": "u", "ñ": "n",
    "ç": "c", "ş": "s", "ğ": "g",
})


def fold(text: str) -> str:
    """Ohne Akzente (gleiche Regeln wie lib/core/learning/grading.dart)."""
    return unicodedata.normalize("NFC", normalize(text)).translate(_FOLD).replace("ß", "ss")


# JSON-Schema für Structured Outputs (generate.py)
ENTRY_JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "entries": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "lemma": {"type": "string"},
                    "pos": {"type": "string", "enum": list(POS)},
                    "gender": {"type": ["string", "null"], "enum": ["m", "f", "mf", None]},
                    "cefr_level": {"type": "string", "enum": list(CEFR)},
                    "translations_de": {"type": "array", "items": {"type": "string"}},
                    "example_sentence": {"type": "string"},
                    "example_translation": {"type": "string"},
                    "forms": {"type": "array", "items": {"type": "string"}},
                    "tags": {"type": "array", "items": {"type": "string", "enum": list(TAGS)}},
                },
                "required": [
                    "lemma", "pos", "gender", "cefr_level", "translations_de",
                    "example_sentence", "example_translation", "forms", "tags",
                ],
                "additionalProperties": False,
            },
        }
    },
    "required": ["entries"],
    "additionalProperties": False,
}
