import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// Lokale Nutzerdatenbank. Die mitgelieferte Vokabeldatenbank ist eine
/// separate, schreibgeschützte Datei (siehe Meilenstein 4).
@DriftDatabase(
  tables: [
    Folders,
    Sets,
    Cards,
    DiagramPoints,
    ReviewStates,
    ReviewLogs,
    GameScores,
    Settings,
    MediaBlobs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'barstardo_learning',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Schema 2: FSRS-Bewertung im Abfrageprotokoll
        await m.addColumn(reviewLogs, reviewLogs.rating);
      }
      if (from < 3) {
        // Schema 3: Medien-Ablage für die Web-Version
        await m.createTable(mediaBlobs);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<String?> readSetting(String key) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<Map<String, String>> readAllSettings() async {
    final rows = await select(settings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<void> writeSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}
