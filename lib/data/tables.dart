import 'package:drift/drift.dart';

/// Ordner zum Sortieren von Sets.
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Ein Vokabel-Set (Fremdsprache ↔ Deutsch).
@DataClassName('VocabSet')
class Sets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get folderId => integer().nullable().references(
    Folders,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text().withLength(min: 1, max: 300)();

  /// ISO-639-1-Code der Fremdsprache, z. B. `es` oder `tr`.
  TextColumn get language => text().withLength(min: 2, max: 8)();
  BoolColumn get ttsEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get goalDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Eine Karteikarte. Vorderseite = Fremdwort, Rückseite = Deutsch.
@DataClassName('VocabCard')
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId =>
      integer().references(Sets, #id, onDelete: KeyAction.cascade)();
  TextColumn get front => text()();
  TextColumn get back => text()();

  /// Rich-Text als JSON (fett, kursiv, Farbe); null = nur Klartext.
  TextColumn get frontRich => text().nullable()();
  TextColumn get backRich => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  /// Verweis auf einen Eintrag der mitgelieferten Vokabeldatenbank.
  IntColumn get vocabId => integer().nullable()();
  BoolColumn get verified => boolean().withDefault(const Constant(true))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Punkte auf einem Diagramm-Bild; jeder Punkt gehört zu einer Karte.
class DiagramPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId =>
      integer().references(Sets, #id, onDelete: KeyAction.cascade)();
  TextColumn get imagePath => text()();

  /// Relative Koordinaten (0..1).
  RealColumn get x => real()();
  RealColumn get y => real()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
}

/// FSRS-Zustand pro Karte.
class ReviewStates extends Table {
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get due => dateTime()();
  RealColumn get stability => real().withDefault(const Constant(0))();
  RealColumn get difficulty => real().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReview => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {cardId};
}

/// Protokoll jeder Abfrage (für Statistiken und adaptives Lernen).
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get mode => text()();
  BoolColumn get correct => boolean()();

  /// FSRS-Bewertung 1–4 (ab Schema 2).
  IntColumn get rating => integer().nullable()();
  IntColumn get responseMs => integer().nullable()();
}

/// Bestwerte in den Spielen.
class GameScores extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId =>
      integer().references(Sets, #id, onDelete: KeyAction.cascade)();
  TextColumn get game => text()();
  IntColumn get score => integer()();
  IntColumn get timeMs => integer().nullable()();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Einfacher Key-Value-Speicher für Einstellungen.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Bilder/Audio im Browser (Web hat kein Dateisystem). Auf dem Handy leer.
class MediaBlobs extends Table {
  TextColumn get key => text()();
  BlobColumn get data => blob()();

  @override
  Set<Column> get primaryKey => {key};
}
