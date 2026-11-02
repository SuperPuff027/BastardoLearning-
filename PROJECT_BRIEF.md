# Project Brief – Barstardo Learning

**Stand:** 02.11.2026 · **Owner:** SuperPuff (Yunus) · **Umsetzung:** mit Claude Code

## 1. Ziel

Barstardo Learning ist eine Vokabel-App für iPhone und Android mit dem Funktionsumfang von Quizlet, aber:

- **komplett offline**, ohne Account, alle Daten nur lokal auf dem Gerät,
- **KI-gestützt**: Wörter werden aus Fotos (Buchseiten, Arbeitsblätter, Schilder, Speisekarten) erkannt, die Sprache wird bestimmt, und daraus entstehen automatisch Karteikarten,
- mit **vorgefertigter, KI-generierter Vokabeldatenbank** für Spanisch und Türkisch.

**Sprachpaare v1:** Spanisch ↔ Deutsch, Türkisch ↔ Deutsch.
Vorderseite = Fremdwort, Rückseite = deutsche Übersetzung; Abfragerichtung im Lernmodus gemischt.

## 2. Nicht-Ziele (bewusst ausgeschlossen)

- Kein Account, kein Login, kein Cloud-Sync, keine Geräte-Synchronisierung
- Kein Teilen, keine öffentlichen Sets, keine Klassen/Gruppen, kein gemeinsames Bearbeiten
- Kein Quizlet Live / Multiplayer
- Kein Spell-Modus (Hören → Schreiben)
- Keine Lehrbuch-Lösungen (Expert Solutions)
- Keine Werbung, kein Tracking, keine Analytics an Dritte

## 3. Kernfunktion: Foto → Karteikarten

**Ablauf**
1. Nutzer fotografiert eine Seite oder wählt ein Bild aus der Galerie.
2. Texterkennung (OCR) on-device.
3. Spracherkennung pro Wort/Zeile on-device (Text kann gemischt Deutsch/Spanisch sein).
4. Nutzer wählt die Zielsprache (z. B. „nur Spanisch").
5. Wörter dieser Sprache werden extrahiert, **auf die Grundform zurückgeführt** (Lemmatisierung, s. u.), dedupliziert und mit der Vokabeldatenbank abgeglichen.
6. Vorschau-Liste: Nutzer hakt Wörter ab, korrigiert Übersetzungen, entfernt Rauschen (Zahlen, Namen, Artikel).
7. Set wird erstellt (neu oder an bestehendes Set angehängt).

**Lemmatisierung ist Pflicht, nicht optional:**
- Spanisch: konjugierte Verben → Infinitiv (*comimos* → *comer*), Plural → Singular, Artikel/Genus erhalten (*la casa*).
- Türkisch ist agglutinierend: *evlerimizde* („in unseren Häusern") → *ev*. Ohne Suffix-Zerlegung findet der Datenbankabgleich fast nichts. Optional die Originalform als Beispiel auf der Karte behalten.

**Übersetzung:** zuerst Lookup in der lokalen Vokabeldatenbank; falls nicht vorhanden, On-device-Übersetzung; Ergebnis als „unbestätigt" markiert, bis der Nutzer es akzeptiert.

## 4. Funktionsumfang v1 (ausgewählt aus der Quizlet-Liste)

### A. Sets erstellen
| # | Funktion | Details |
|---|---|---|
| 1 | Sets anlegen | Vorgefertigte KI-Sets (Spanisch, Türkisch) + Erstellung per Foto + manuelles Anlegen und Erweitern |
| 2 | Bilder auf Karten | optional pro Karte, aus Kamera/Galerie (offline: keine Websuche) |
| 3 | Audio | **Eigene Aufnahme** der Aussprache pro Karte. **Vorlesen (TTS)**: beim Anlegen eines Sets wählbar (Standard: aus) + globaler Schalter in den Einstellungen |
| 4 | Übersetzungsvorschläge | beim Tippen, aus der lokalen Datenbank, sonst On-device-Übersetzung |
| 5 | Text-Import | Einfügen aus Excel/Word/Text, Trennzeichen wählbar (Tab, Komma, Semikolon, „-") |
| 6 | Rich Text | fett, kursiv, Farbe |
| 7 | Diagramm-Sets | Bild hochladen, Punkte darauf setzen, jeder Punkt = Karte (z. B. „Küche" mit beschrifteten Gegenständen) |
| 8 | KI-Generierung aus Notizen/Fotos | = Kernfunktion Abschnitt 3, zusätzlich aus eingefügtem Text |
| 9 | Ordner | Sets in Ordnern sortieren |
| 10 | Kopieren & Zusammenführen | lokal |

### B. Lernmodi
| # | Funktion | Details |
|---|---|---|
| 11 | Karteikarten | umdrehen, wischen (gewusst/nicht gewusst), mischen |
| 12 | Learn | adaptiv, falsche Karten kommen öfter, Fragetypen gemischt |
| 13 | Write | Antwort eintippen |
| 15 | Test | Multiple Choice, Wahr/Falsch, Freitext, Zuordnen; Typen und Anzahl wählbar |
| 16 | Spaced Repetition | Algorithmus: FSRS (Alternative SM-2); Fälligkeiten pro Karte |
| 17 | Abfragerichtung | **Standard: gemischt**; umstellbar auf Fremdwort→DE oder DE→Fremdwort |
| 18 | Smarte Bewertung | toleriert fehlende Akzente (á/a, ñ/n, ş/s, ğ/g, ı/i, ç/c) als „fast richtig", Groß/Klein egal, Artikel optional, Tippfehler mit Levenshtein ≤ 1 bei Wörtern ≥ 5 Zeichen; Nutzer kann „Ich hatte recht" überschreiben |
| 19 | Markierte Karten | Sternchen, „nur markierte lernen" |

### C. Spiele
| # | Funktion | Details |
|---|---|---|
| 20 | Match | 6 Paare auf Zeit zuordnen, Bestzeit pro Set |
| 21 | Gravity | Wörter fallen, Antwort tippen, Level steigen |
| 22 | Blast | Asteroiden mit Antworten, richtigen antippen |

### D. KI-Extras
| # | Funktion | Details |
|---|---|---|
| 24 | KI-Tutor | Chat, der die Karten des Sets abfragt, Beispielsätze bildet, nachfragt |
| 25 | Erklärungen | bei falscher Antwort: warum, Grammatikhinweis, Beispielsatz |
| 26 | Lernleitfaden | Zusammenfassung eines Sets: Wortgruppen, Grammatikmuster, Merkhilfen |

→ Siehe Abschnitt 6: Diese drei brauchen ein Sprachmodell, und das ist mit „offline" der schwierigste Teil des Projekts.

### E. Fortschritt & Motivation
| # | Funktion | Details |
|---|---|---|
| 27 | Fortschritt pro Set | nicht gelernt / lernend / gemeistert |
| 28 | Statistiken | Lernzeit, Karten pro Tag, Trefferquote, Verlauf |
| 29 | Streaks & Erinnerungen | lokale Benachrichtigungen; **global abschaltbar**, Uhrzeit wählbar |
| 30 | Lernziele | Zieldatum pro Set → App verteilt Pensum auf die Tage |

### G. Plattform
| # | Funktion | Details |
|---|---|---|
| 35 | Offline | alles funktioniert ohne Internet |
| 37 | Kein Account | – |
| 38 | Dark Mode | Hell / Dunkel / System |
| – | Speicherung | nur lokal (SQLite), keine Cloud |

## 5. Vokabeldatenbank (KI-generiert)

**Ziel:** so groß wie möglich bei vertretbarer Qualität. Vorschlag für v1: **je ~10.000 Lemmata** für Spanisch und Türkisch, sortiert nach Häufigkeit; später erweiterbar (Datenbank-Updates als Teil von App-Updates).

**Schema pro Eintrag**
- `lemma`, `language` (es/tr), `pos` (Wortart), `gender` + Artikel (nur es), `cefr_level` (A1–C2), `frequency_rank`
- `translations_de[]` (mehrere Bedeutungen, Hauptbedeutung zuerst)
- `example_sentence` + Übersetzung
- `forms[]` (wichtige Beugungsformen, dient auch der Lemmatisierung)
- `tags[]` (Thema: Essen, Reisen, Familie …)
- `verified` (bool)

**Erstellung (einmalig, zur Build-Zeit, nicht in der App):**
1. Häufigkeitsliste als Wortbasis (z. B. aus OpenSubtitles-/Wiktionary-Daten, **Lizenz prüfen**, viele sind CC-BY-SA → Namensnennung in der App nötig).
2. LLM füllt Übersetzungen, Beispielsätze, Wortart, Niveau.
3. Automatische Plausibilitätsprüfung (zweiter LLM-Durchlauf, Abgleich mit Wörterbuchdaten); Unstimmigkeiten → `verified = false`.
4. Export als SQLite-Datei, die mit der App ausgeliefert wird.

**Wichtig:** KI-generierte Übersetzungen sind bei 10.000 Wörtern nicht fehlerfrei. Die App zeigt unbestätigte Einträge erkennbar an und lässt jede Karte bearbeiten.

**Vorgefertigte Sets:** aus der Datenbank nach Niveau (A1, A2, …) und Thema, z. B. „Spanisch A1 – Essen & Trinken".

## 6. Offline vs. KI – technische Entscheidung

| Funktion | Offline machbar? | Lösung |
|---|---|---|
| OCR | ja | Google ML Kit Text Recognition (on-device, lateinische Schrift reicht für es/tr/de) |
| Spracherkennung | ja | ML Kit Language Identification (on-device) |
| Übersetzung einzelner Wörter | ja | Datenbank + ML Kit On-device Translation (Sprachmodelle ca. 30 MB pro Sprache, einmaliger Download) |
| Lemmatisierung | ja | Formen-Tabelle aus der Datenbank + regelbasierte Suffix-Zerlegung (Türkisch) |
| TTS | ja | System-TTS (iOS/Android), Sprachpakete es/tr prüfen |
| KI-Tutor, Erklärungen, Leitfaden (24–26) | **eingeschränkt** | siehe unten |

**Für 24–26 braucht es ein Sprachmodell.** Optionen:
- **A (Vorschlag): kleines On-device-LLM** (z. B. Gemma 3 1B oder Qwen 2.5 1.5B, quantisiert, ca. 0,7–1 GB), optionaler Download in den Einstellungen, Ausführung über llama.cpp. Läuft ohne Internet; auf älteren Handys langsam; Qualität für Spanisch ordentlich, für Türkisch schwächer.
- **B: System-KI** (Apple Foundation Models ab iOS 26 auf Apple-Intelligence-Geräten; Gemini Nano auf einigen Android-Geräten). Kostenlos und schnell, aber nur auf neueren Geräten.
- **C: Online-API als Opt-in** (bricht „nur offline").

**Empfehlung:** A als Basis, B nutzen, wo verfügbar. Ohne Modell sind 24–26 ausgeblendet; der Rest der App bleibt voll nutzbar.

## 7. Tech-Stack

- **Flutter** (eine Codebasis für iOS + Android)
- State: Riverpod · Navigation: go_router
- Datenbank: SQLite via **Drift**
- Pakete: `google_mlkit_text_recognition`, `google_mlkit_language_id`, `google_mlkit_translation`, `flutter_tts`, `record` + `just_audio`, `flutter_local_notifications`, `image_picker`/`camera`
- LLM: llama.cpp-Binding (z. B. `fllama` / `llama_cpp_dart`), Prüfung im Spike
- Medien (Bilder, Aufnahmen) als Dateien im App-Verzeichnis, Pfade in der DB

## 8. Datenmodell (grob)

- `folders` (id, name)
- `sets` (id, folder_id, title, language, tts_enabled, goal_date, created_at)
- `cards` (id, set_id, front, back, front_rich, back_rich, image_path, audio_path, starred, vocab_id?, verified)
- `diagram_points` (id, set_id, image_path, x, y, card_id)
- `review_state` (card_id, due, stability, difficulty, reps, lapses, last_review): FSRS
- `review_log` (card_id, timestamp, mode, correct, response_ms)
- `game_scores` (set_id, game, score, time)
- `settings` (key, value)
- `vocab` (mitgelieferte Datenbank, read-only, separate DB-Datei)

## 9. Plattform-Hinweise

- **iOS bauen erfordert macOS.** Ohne Mac: GitHub Actions (macOS-Runner) oder Codemagic.
- **Auf das iPhone installieren:** dauerhaft nur mit Apple Developer Account (99 €/Jahr, dann TestFlight). Mit kostenlosem Account laufen Apps nur 7 Tage und müssen neu signiert werden.
- Android: APK direkt installierbar.
- Lokale Daten gehen beim Löschen der App oder Verlust des Handys verloren (Folge der Entscheidung „nur lokal").

## 10. Meilensteine

0. **GitHub-Repo anlegen:** Repository `Barstardo-Learning` auf dem GitHub-Account `SuperPuff027` erstellen (privat), Branch `main`. Diesen Brief, `README.md` und `CLAUDE.md` als ersten Commit hochladen. Danach alle weiteren Meilensteine als Branch + Pull Request in diesem Repo.
1. **Grundgerüst:** Flutter-Projekt, Drift-DB, Navigation, Dark Mode, Einstellungen
2. **Sets & Karten manuell:** 1, 2, 5, 6, 9, 10, 19
3. **Lernmodi:** 11, 13, 17, 18, dann 12, 15, 16
4. **Vokabeldatenbank:** Generierungs-Pipeline (Skripte im Repo unter `/tools/vocab`), erst 1.000 Wörter pro Sprache, dann skalieren; vorgefertigte Sets
5. **Foto → Karten:** OCR, Spracherkennung, Lemmatisierung, Vorschau (3, 4, 8)
6. **Audio:** Aufnahme + TTS-Schalter (3)
7. **Spiele:** 20, 21, 22
8. **Fortschritt & Motivation:** 27–30, Benachrichtigungen abschaltbar
9. **Diagramm-Sets** (7)
10. **KI-Extras:** Spike On-device-LLM, dann 24, 25, 26
11. **iOS-Build-Pipeline** + Release

## 11. Offene Entscheidungen

1. **KI-Extras (24–26):** Option A, B oder C aus Abschnitt 6?
2. **Backup:** Ein lokaler Export/Import als Datei (kein Cloud-Sync) würde Datenverlust bei Handywechsel verhindern. Rein oder raus?
3. **Größe der Datenbank v1:** 10.000 Wörter pro Sprache ok, oder mehr (App wird größer, Fehlerquote steigt)?
4. **Apple Developer Account** vorhanden bzw. geplant?
5. **Weitere Sprachen später** (Architektur ist sprachneutral vorbereitet)?
