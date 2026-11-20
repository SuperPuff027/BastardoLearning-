# Vokabeldatenbank (`tools/vocab`)

Erzeugt `assets/vocab/vocab.db`, die schreibgeschützt mit der App ausgeliefert wird.
Die App braucht dafür weder Internet noch einen API-Schlüssel.

## Ablauf

```bash
cd tools/vocab
python3 import_seed.py      # seed/<lang>_*.txt  → data/<lang>.jsonl
python3 validate.py         # Prüfung, Häufigkeitsrang, verified
python3 build_db.py         # data/*.jsonl       → assets/vocab/vocab.db
python3 -m unittest test_pipeline
```

`validate.py` lädt beim ersten Lauf die Häufigkeitslisten nach `data/freq_<lang>.txt`
(nicht im Repo, siehe `.gitignore`).

## Daten

| Datei | Inhalt |
|---|---|
| `seed/<lang>_NN.txt` | Quelle: kompakte Zeilen `lemma\|pos\|genus\|niveau\|übersetzungen\|beispiel\|beispiel_de\|formen\|themen` |
| `data/<lang>.jsonl` | Ein Eintrag pro Zeile, inkl. stabiler `id`, `frequency_rank`, `verified`, `issues` |

**Stand v1:** je ~1.000 Lemmata für Spanisch und Türkisch. Erstellt mit Claude im
Entwicklungs-Chat (ohne API), nach Häufigkeit ausgewählt.

**Stabile IDs:** Karten in der App verweisen per `vocab_id` auf Einträge. IDs werden beim
ersten Build vergeben und in `data/*.jsonl` gespeichert. Einträge nie neu nummerieren;
gelöschte IDs nicht wiederverwenden.

**`verified`** bedeutet: Die automatische Prüfung ist bestanden (Wortart, Niveau, Thema,
Genus bei spanischen Nomen, Artikel in der deutschen Übersetzung, Beispielsatz enthält
das Wort, keine Doppelung). Es ist keine menschliche Kontrolle; Fehler in Übersetzungen
sind möglich. Die App lässt jede Karte bearbeiten.

## Erweitern (geplant)

Mehr Wörter sollen aus freien Wiktionary-Daten (CC BY-SA) kommen. Dafür braucht die
Umgebung Netzwerkzugriff auf `kaikki.org` bzw. `dumps.wikimedia.org`.

## Lizenzen

- Häufigkeitslisten: [FrequencyWords](https://github.com/hermitdave/FrequencyWords)
  (Hermit Dave, OpenSubtitles 2018), Inhalt CC BY-SA 4.0. Die Namensnennung steht in der
  App unter Einstellungen → „Über die App & Lizenzen“ und in der Tabelle `meta` der DB.

## Kursordner (`courses/`)

Die App legt beim ersten Start Kursordner an. `build_db.py` schreibt sie in die
Tabellen `course` und `course_card` von `assets/vocab/vocab.db`:

| Schlüssel | Ordner | Quelle |
|---|---|---|
| `es_b1_aula3` | Spanisch B1 – Aula 3 (Unidad 1–12) | `courses/es_b1_aula3.csv` |
| `es_a2` | Spanisch A2 (nach Thema) | `data/es.jsonl`, Niveau A2 |
| `tr_uni_1_2` | Türkisch I + II (Uni) | `courses/tr_uni_tuerkisch_1_2.csv` |
| `tr_suffixe` | Türkisch Suffixe (Regeln, Endungen, Kombinationen) | `courses/tr_suffixe.tsv` |
| `tr_a1`, `tr_a2`, `tr_b1_b2` | Türkisch A1, A2, B1/B2 (nach Thema) | `data/tr.jsonl` |

Spanisch A1/B1/B2 aus `data/es.jsonl` bleiben im Wörterbuch (für Erkennung und
Vorschläge), bekommen aber keinen eigenen Ordner.

Die beiden CSV-Dateien sind geprüfte Abschriften der Lehrbuch-PDFs; Prüfbericht
und neu gesetzte PDFs liegen in `docs/vokabeln/`.

```bash
python3 courses/make_pdfs.py   # PDFs in docs/vokabeln/ erzeugen
python3 courses/check_pdfs.py  # PDFs gegen die CSV-Dateien prüfen
```
