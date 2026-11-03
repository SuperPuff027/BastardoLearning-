import 'dart:convert';
import 'dart:io';

import 'package:barstardo_learning/core/learning/fsrs.dart';
import 'package:barstardo_learning/core/rich_text.dart';
import 'package:barstardo_learning/data/backup.dart';
import 'package:barstardo_learning/data/database.dart';
import 'package:barstardo_learning/data/library_repository.dart';
import 'package:barstardo_learning/data/media/file_media_store.dart';
import 'package:barstardo_learning/data/study_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tmp = Directory.systemTemp.createTempSync('backup_test');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  AppDatabase newDb() => AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );

  test('Export und Wiederherstellung: alles kommt zurück', () async {
    final db = newDb();
    final media = FileMediaStore(Directory('${tmp.path}/a'));
    final repo = LibraryRepository(db, media);
    final folder = await repo.createFolder('Schule');
    final setId = await repo.createSet(
      title: 'Spanisch',
      language: 'es',
      folderId: folder,
    );
    final img = await media.importBytes(
      Uint8List.fromList([1, 2, 3]),
      extension: '.png',
    );
    final cardId = await repo.addCard(
      setId,
      CardDraft(
        front: RichDocument(const [
          RichSpan('la ', RichStyle()),
          RichSpan('casa', RichStyle(bold: true)),
        ]),
        back: RichDocument.plain('das Haus'),
        imagePath: img,
        starred: true,
        vocabId: 1000005,
      ),
    );
    await StudyRepository(db)
        .record(cardId: cardId, mode: StudyMode.review, rating: Rating.good);
    await db.writeSetting('theme_mode', 'dark');

    final bytes = await BackupService(db, media).export();
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(json['format'], BackupService.format);
    expect((json['media'] as Map), hasLength(1));

    // In eine leere App (anderes Gerät) einspielen
    final db2 = newDb();
    final media2 = FileMediaStore(Directory('${tmp.path}/b'));
    final service2 = BackupService(db2, media2);
    final info = service2.inspect(bytes);
    expect(info.sets, 1);
    expect(info.cards, 1);
    await service2.restore(bytes);

    final card = (await db2.select(db2.cards).get()).single;
    expect(card.front, 'la casa');
    expect(card.frontRich, isNotNull);
    expect(card.starred, isTrue);
    expect(card.vocabId, 1000005);
    expect(await media2.read(card.imagePath), [1, 2, 3]);
    final set = (await db2.select(db2.sets).get()).single;
    expect(set.folderId, isNotNull);
    expect((await db2.select(db2.reviewStates).get()).single.reps, 1);
    expect(await db2.readSetting('theme_mode'), 'dark');

    await db.close();
    await db2.close();
  });

  test('Wiederherstellen ersetzt vorhandene Daten und Bilder', () async {
    final db = newDb();
    final media = FileMediaStore(Directory('${tmp.path}/c'));
    final repo = LibraryRepository(db, media);
    final empty = await BackupService(db, media).export();

    final setId = await repo.createSet(title: 'Alt', language: 'tr');
    final img = await media.importBytes(
      Uint8List.fromList([9]),
      extension: '.jpg',
    );
    await repo.addCard(
      setId,
      CardDraft(
        front: RichDocument.plain('ev'),
        back: RichDocument.plain('Haus'),
        imagePath: img,
      ),
    );

    await BackupService(db, media).restore(empty);
    expect(await db.select(db.sets).get(), isEmpty);
    expect(await db.select(db.cards).get(), isEmpty);
    expect(await media.read(img), isNull);
    await db.close();
  });

  test('Ungültige Dateien werden abgelehnt', () async {
    final db = newDb();
    final service = BackupService(
      db,
      FileMediaStore(Directory('${tmp.path}/d')),
    );
    expect(
      () => service.inspect(Uint8List.fromList(utf8.encode('kein json'))),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => service.inspect(
        Uint8List.fromList(utf8.encode(jsonEncode({'format': 'anderes'}))),
      ),
      throwsA(isA<BackupException>()),
    );
    final future = jsonEncode({
      'format': BackupService.format,
      'schema': 999,
      'tables': <String, dynamic>{},
      'media': <String, dynamic>{},
    });
    expect(
      () => service.inspect(Uint8List.fromList(utf8.encode(future))),
      throwsA(isA<BackupException>()),
    );
    await db.close();
  });
}
