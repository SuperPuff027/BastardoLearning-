"""Tests der Vokabel-Pipeline: python3 -m unittest test_pipeline (in tools/vocab)."""

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import build_db
import validate
from import_seed import parse_line
from vocab_schema import Entry, fold, normalize


def entry(**kw) -> Entry:
    base = dict(lemma="casa", language="es", pos="noun", gender="f", cefr_level="A1",
                translations_de=["das Haus"], example_sentence="Mi casa es pequeña.",
                example_translation="Mein Haus ist klein.", forms=["casas"], tags=["wohnen"])
    base.update(kw)
    return Entry(**base)


class SchemaTest(unittest.TestCase):
    def test_normalize_and_fold(self):
        self.assertEqual(normalize("  ¡Hola! "), "hola")
        self.assertEqual(normalize("İSTANBUL"), "istanbul")
        self.assertEqual(fold("Niño"), "nino")
        self.assertEqual(fold("ışık"), "isik")
        self.assertEqual(fold("Füße"), "fusse")

    def test_article(self):
        self.assertEqual(entry().article, "la")
        self.assertEqual(entry(gender="m", lemma="perro").article, "el")
        self.assertIsNone(entry(language="tr", gender=None).article)


class SeedTest(unittest.TestCase):
    def test_parse_line(self):
        e = parse_line("casa|noun|f|A1|das Haus;das Zuhause|Mi casa.|Mein Haus.|casas|wohnen", "es")
        self.assertEqual(e.translations_de, ["das Haus", "das Zuhause"])
        self.assertEqual(e.forms, ["casas"])
        self.assertEqual(e.gender, "f")

    def test_wrong_field_count(self):
        with self.assertRaises(ValueError):
            parse_line("casa|noun|f", "es")


class ValidateTest(unittest.TestCase):
    def test_ok(self):
        self.assertEqual(validate.check(entry(), set()), [])

    def test_issues(self):
        issues = validate.check(entry(gender=None, translations_de=["Haus"],
                                      example_sentence="Otra frase.", tags=[]), set())
        self.assertIn("Genus fehlt", issues)
        self.assertIn("Deutsche Hauptübersetzung ohne Artikel", issues)
        self.assertIn("Beispielsatz enthält weder Lemma noch eine Form", issues)
        self.assertIn("Kein Thema", issues)

    def test_turkish_suffix_in_example(self):
        e = entry(language="tr", lemma="ev", gender=None, forms=[],
                  example_sentence="Evlerimizde bahçe var.")
        self.assertEqual(validate.check(e, set()), [])

    def test_duplicate(self):
        self.assertIn("Doppelter Eintrag", validate.check(entry(), {("casa", "noun")}))


class BuildTest(unittest.TestCase):
    def test_build_assigns_stable_ids_and_lookups(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            (tmp / "data").mkdir()
            e = entry()
            (tmp / "data" / "es.jsonl").write_text(e.to_json() + "\n", encoding="utf-8")
            old_root = build_db.ROOT
            build_db.ROOT = tmp
            try:
                out = tmp / "vocab.db"
                build_db.build(["es"], out)
                first_id = json.loads((tmp / "data" / "es.jsonl").read_text())["id"]
                build_db.build(["es"], out)  # zweiter Lauf: ID bleibt
                self.assertEqual(json.loads((tmp / "data" / "es.jsonl").read_text())["id"], first_id)
                db = sqlite3.connect(out)
                forms = {r[0] for r in db.execute("SELECT form FROM vocab_form")}
                self.assertEqual(forms, {"casa", "la casa", "casas"})
                de = [r[0] for r in db.execute("SELECT de FROM vocab_de")]
                self.assertEqual(de, ["haus"])
                db.close()
            finally:
                build_db.ROOT = old_root


if __name__ == "__main__":
    unittest.main()
