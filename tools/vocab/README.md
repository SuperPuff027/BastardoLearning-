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
