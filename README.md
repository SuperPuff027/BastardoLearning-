# Barstardo Learning

KI-gestützte Vokabel-App für iPhone und Android, offline und ohne Account.
Fotografiere eine Seite → die App erkennt die Wörter und die Sprache und macht daraus Karteikarten.

**Sprachen:** Spanisch ↔ Deutsch, Türkisch ↔ Deutsch

Details: [PROJECT_BRIEF.md](PROJECT_BRIEF.md)

## Entwicklung

Voraussetzung: Flutter (stable).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift-Code erzeugen
flutter analyze
flutter test
flutter run
```

### Struktur

| Pfad | Inhalt |
|---|---|
| `lib/app/` | App-Root, Theme, Navigation (go_router), Riverpod-Provider |
| `lib/data/` | Drift-Datenbank (`tables.dart`, `database.dart`) |
| `lib/features/` | Bereiche: `library` (Sets), `learn`, `progress`, `settings` |
| `tools/vocab/` | Skripte zur Generierung der Vokabeldatenbank (ab Meilenstein 4) |
| `assets/vocab/` | Generierte Vokabeldatenbank (ab Meilenstein 4) |
