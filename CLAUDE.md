# CLAUDE.md – Barstardo Learning

Lies zuerst `PROJECT_BRIEF.md`. Es ist die verbindliche Spezifikation.

## Harte Regeln
- **Offline-first:** Keine Funktion darf eine Internetverbindung voraussetzen. Ausnahme: einmalige, optionale Downloads von Sprach-/KI-Modellen.
- **Kein Account, kein Backend, keine Analytics, keine Werbe-SDKs.**
- Alle Nutzerdaten nur lokal (SQLite via Drift + Dateien im App-Verzeichnis).
- Eine Codebasis für iOS und Android (Flutter). Kein plattformspezifischer Code ohne Grund.
- Push/Erinnerungen und TTS müssen in den Einstellungen abschaltbar sein.
- Dark Mode: Hell / Dunkel / System.

## Arbeitsweise
- Meilensteine aus `PROJECT_BRIEF.md` Abschnitt 10 der Reihe nach umsetzen; pro Meilenstein ein Branch + PR.
- Nach jeder Änderung: `flutter analyze` und `flutter test` müssen grün sein.
- Lernlogik (FSRS, Bewertung mit Akzent-Toleranz, Lemmatisierung) mit Unit-Tests abdecken.
- Vokabel-Generierung lebt in `tools/vocab/` (Skripte), nicht im App-Code. Generierte DB nach `assets/vocab/`.
- UI-Texte auf Deutsch.
- Offene Entscheidungen (Brief Abschnitt 11) nicht selbst treffen, sondern nachfragen.
