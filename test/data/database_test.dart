import 'package:barstardo_learning/data/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => db.close());

  test('Einstellungen schreiben, lesen und überschreiben', () async {
    expect(await db.readSetting('theme_mode'), isNull);
    await db.writeSetting('theme_mode', 'dark');
    expect(await db.readSetting('theme_mode'), 'dark');
    await db.writeSetting('theme_mode', 'light');
    expect(await db.readAllSettings(), {'theme_mode': 'light'});
  });

  test('Set mit Karten anlegen; Löschen des Sets löscht Karten mit', () async {
    final setId = await db
        .into(db.sets)
        .insert(SetsCompanion.insert(title: 'Spanisch A1', language: 'es'));
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            setId: setId,
            front: 'la casa',
            back: 'das Haus',
          ),
        );
    final cards = await db.select(db.cards).get();
    expect(cards, hasLength(1));
    expect(cards.single.starred, isFalse);
    expect(cards.single.verified, isTrue);

    await (db.delete(db.sets)..where((s) => s.id.equals(setId))).go();
    expect(await db.select(db.cards).get(), isEmpty);
  });

  test('Löschen eines Ordners behält die Sets (folder_id wird null)', () async {
    final folderId = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(name: 'Schule'));
    await db
        .into(db.sets)
        .insert(
          SetsCompanion.insert(
            title: 'Türkisch Basics',
            language: 'tr',
            folderId: Value(folderId),
          ),
        );
    await (db.delete(db.folders)..where((f) => f.id.equals(folderId))).go();
    final set = await db.select(db.sets).getSingle();
    expect(set.folderId, isNull);
    expect(set.ttsEnabled, isFalse);
  });
}
