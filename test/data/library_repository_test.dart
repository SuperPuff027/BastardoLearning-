import 'dart:io';

import 'package:barstardo_learning/core/import_parser.dart';
import 'package:barstardo_learning/core/rich_text.dart';
import 'package:barstardo_learning/data/database.dart';
import 'package:barstardo_learning/data/library_repository.dart';
import 'package:barstardo_learning/data/media/file_media_store.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FileMediaStore media;
  late LibraryRepository repo;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    tmp = await Directory.systemTemp.createTemp('barstardo_test');
    media = FileMediaStore(tmp);
    repo = LibraryRepository(db, media);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  CardDraft draft(
    String front,
    String back, {
    String? image,
    bool starred = false,
  }) => CardDraft(
    front: RichDocument.plain(front),
    back: RichDocument.plain(back),
    imagePath: image,
    starred: starred,
  );

  Future<String> fakeImage() async {
    final f = File('${tmp.path}/src.jpg')..writeAsStringSync('bild');
    return media.importBytes(f.readAsBytesSync(), extension: '.jpg');
  }

  group('Ordner', () {
    test('anlegen, umbenennen, Anzahl Sets', () async {
      final id = await repo.createFolder('  Schule ');
      await repo.createSet(title: 'A', language: 'es', folderId: id);
      await repo.createSet(title: 'B', language: 'tr');
      var folders = await repo.watchFolders().first;
      expect(folders.single.folder.name, 'Schule');
      expect(folders.single.setCount, 1);

      await repo.renameFolder(id, 'Uni');
      folders = await repo.watchFolders().first;
      expect(folders.single.folder.name, 'Uni');
    });

    test('leerer Name wird abgelehnt', () {
      expect(repo.createFolder('   '), throwsA(isA<ValidationException>()));
    });

    test('Ordner löschen behält Sets, außer deleteSets', () async {
      final f1 = await repo.createFolder('Behalten');
      final f2 = await repo.createFolder('Weg');
      await repo.createSet(title: 'S1', language: 'es', folderId: f1);
      await repo.createSet(title: 'S2', language: 'es', folderId: f2);

      await repo.deleteFolder(f1);
      expect((await repo.watchSets().first).single.set.title, 'S1');

      await repo.deleteFolder(f2, deleteSets: true);
      expect((await repo.watchAllSets().first).map((s) => s.set.title), ['S1']);
    });
  });

  group('Sets und Karten', () {
    test('Set anlegen: TTS standardmäßig aus; Karten zählen', () async {
      final id = await repo.createSet(title: 'Essen', language: 'es');
      await repo.addCard(id, draft('el pan', 'das Brot'));
      await repo.addCard(id, draft('el agua', 'das Wasser'));
      final sets = await repo.watchSets().first;
      expect(sets.single.cardCount, 2);
      expect(sets.single.set.ttsEnabled, isFalse);
      final cards = await repo.watchCards(id).first;
      expect(cards.map((c) => c.position), [0, 1]);
    });

    test('leere Seiten werden abgelehnt, Leerzeichen getrimmt', () async {
      final id = await repo.createSet(title: 'X', language: 'tr');
      expect(
        repo.addCard(id, draft('  ', 'a')),
        throwsA(isA<ValidationException>()),
      );
      expect(
        repo.addCard(id, draft('a', '')),
        throwsA(isA<ValidationException>()),
      );
      final cardId = await repo.addCard(id, draft(' ev ', ' Haus '));
      final card = await repo.getCard(cardId);
      expect(card!.front, 'ev');
      expect(card.back, 'Haus');
    });

    test('Rich Text wird gespeichert, Klartext bleibt durchsuchbar', () async {
      final id = await repo.createSet(title: 'X', language: 'es');
      final cardId = await repo.addCard(
        id,
        CardDraft(
          front: RichDocument(const [
            RichSpan('la '),
            RichSpan('casa', RichStyle(bold: true)),
          ]),
          back: RichDocument.plain('das Haus'),
        ),
      );
      final card = (await repo.getCard(cardId))!;
      expect(card.front, 'la casa');
      expect(card.frontRich, isNotNull);
      expect(card.backRich, isNull);
      expect(
        RichDocument.decode(card.front, card.frontRich).spans.last.style.bold,
        isTrue,
      );
    });

    test('Bearbeiten bestätigt die Karte und räumt altes Bild auf', () async {
      final id = await repo.createSet(title: 'X', language: 'es');
      final img = await fakeImage();
      final cardId = await repo.addCard(id, draft('a', 'b', image: img));
      await (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(
        const CardsCompanion(verified: Value(false)),
      );

      await repo.updateCard(cardId, draft('a', 'c'));
      final card = (await repo.getCard(cardId))!;
      expect(card.back, 'c');
      expect(card.verified, isTrue);
      expect(card.imagePath, isNull);
      expect(media.resolve(img).existsSync(), isFalse);
    });

    test('Markieren und nur markierte anzeigen', () async {
      final id = await repo.createSet(title: 'X', language: 'es');
      final a = await repo.addCard(id, draft('uno', 'eins'));
      await repo.addCard(id, draft('dos', 'zwei'));
      await repo.setStarred(a, true);
      final starred = await repo.watchCards(id, starredOnly: true).first;
      expect(starred.map((c) => c.front), ['uno']);
    });

    test('Karte löschen entfernt das Bild', () async {
      final id = await repo.createSet(title: 'X', language: 'es');
      final img = await fakeImage();
      final cardId = await repo.addCard(id, draft('a', 'b', image: img));
      await repo.deleteCard(cardId);
      expect(media.resolve(img).existsSync(), isFalse);
    });

    test('Set löschen entfernt Karten und Bilder', () async {
      final id = await repo.createSet(title: 'X', language: 'es');
      final img = await fakeImage();
      await repo.addCard(id, draft('a', 'b', image: img));
      await repo.deleteSet(id);
      expect(await db.select(db.cards).get(), isEmpty);
      expect(media.resolve(img).existsSync(), isFalse);
    });

    test('Import hängt Karten hinten an', () async {
      final id = await repo.createSet(title: 'X', language: 'es');
      await repo.addCard(id, draft('cero', 'null'));
      final n = await repo.importCards(id, const [
        ImportedPair('uno', 'eins'),
        ImportedPair('dos', 'zwei'),
      ]);
      expect(n, 2);
      final cards = await repo.watchCards(id).first;
      expect(cards.map((c) => c.front), ['cero', 'uno', 'dos']);
    });
  });

  group('Kopieren & Zusammenführen', () {
    test('Kopie ist unabhängig, inkl. eigener Bilddatei', () async {
      final folder = await repo.createFolder('F');
      final id = await repo.createSet(
        title: 'Reisen',
        language: 'tr',
        folderId: folder,
        ttsEnabled: true,
      );
      final img = await fakeImage();
      await repo.addCard(id, draft('yol', 'Weg', image: img, starred: true));

      final copyId = await repo.copySet(id);
      final copy = (await repo.getSet(copyId))!;
      expect(copy.title, 'Reisen (Kopie)');
      expect(copy.folderId, folder);
      expect(copy.ttsEnabled, isTrue);
      final copied = (await repo.watchCards(copyId).first).single;
      expect(copied.front, 'yol');
      expect(copied.starred, isTrue);
      expect(copied.imagePath, isNot(img));

      await repo.deleteSet(id);
      expect(media.resolve(copied.imagePath!).existsSync(), isTrue);
    });

    test('Zusammenführen kopiert Karten, Quellen bleiben', () async {
      final a = await repo.createSet(title: 'A', language: 'es');
      final b = await repo.createSet(title: 'B', language: 'es');
      await repo.addCard(a, draft('uno', 'eins'));
      await repo.addCard(b, draft('dos', 'zwei'));
      await repo.addCard(b, draft('tres', 'drei'));

      final n = await repo.mergeSets(a, [b]);
      expect(n, 2);
      expect((await repo.watchCards(a).first).map((c) => c.front), [
        'uno',
        'dos',
        'tres',
      ]);
      expect(await repo.watchCards(b).first, hasLength(2));
    });

    test('Zusammenführen mit Löschen verschiebt Karten', () async {
      final a = await repo.createSet(title: 'A', language: 'es');
      final b = await repo.createSet(title: 'B', language: 'es');
      final img = await fakeImage();
      await repo.addCard(b, draft('dos', 'zwei', image: img));

      await repo.mergeSets(a, [b], deleteSources: true);
      expect(await repo.getSet(b), isNull);
      final moved = (await repo.watchCards(a).first).single;
      expect(moved.imagePath, img);
      expect(media.resolve(img).existsSync(), isTrue);
    });

    test('verschiedene Sprachen können nicht zusammengeführt werden', () async {
      final a = await repo.createSet(title: 'A', language: 'es');
      final b = await repo.createSet(title: 'B', language: 'tr');
      expect(repo.mergeSets(a, [b]), throwsA(isA<ValidationException>()));
    });
  });

  group('Duplikate & Vokabeldatenbank', () {
    test('duplicateKey ignoriert Artikel, Groß/Klein, Satzzeichen', () {
      expect(duplicateKey('La Casa.'), 'casa');
      expect(duplicateKey('casa'), 'casa');
      expect(duplicateKey('sí'), isNot(duplicateKey('si')));
    });

    test('findDuplicates: gleiches Set zuerst, andere Sprache nicht', () async {
      final a = await repo.createSet(title: 'A', language: 'es');
      final b = await repo.createSet(title: 'B', language: 'es');
      final t = await repo.createSet(title: 'T', language: 'tr');
      await repo.addCard(b, draft('la casa', 'das Haus'));
      final own = await repo.addCard(a, draft('casa', 'Haus'));
      await repo.addCard(t, draft('casa', 'x'));

      final hits = await repo.findDuplicates('es', 'Casa', preferSetId: a);
      expect(hits.map((h) => h.set.title), ['A', 'B']);
      final withoutSelf = await repo.findDuplicates(
        'es',
        'casa',
        excludeCardId: own,
        preferSetId: a,
      );
      expect(withoutSelf.map((h) => h.set.title), ['B']);
    });

    test('duplicateIdsIn markiert alle Kopien', () async {
      final a = await repo.createSet(title: 'A', language: 'es');
      final c1 = await repo.addCard(a, draft('el perro', 'Hund'));
      final c2 = await repo.addCard(a, draft('perro', 'der Hund'));
      await repo.addCard(a, draft('gato', 'Katze'));
      final cards = await repo.watchCards(a).first;
      expect(LibraryRepository.duplicateIdsIn(cards), {c1, c2});
    });

    test('Karte mit vocabId; addVocabCards übernimmt verified', () async {
      final a = await repo.createSet(title: 'A', language: 'es');
      final id = await repo.addCard(
        a,
        CardDraft(
          front: RichDocument.plain('la casa'),
          back: RichDocument.plain('das Haus'),
          vocabId: 1000123,
          verified: false,
        ),
      );
      final card = (await repo.getCard(id))!;
      expect(card.vocabId, 1000123);
      expect(card.verified, isFalse);

      await repo.addVocabCards(a, const [
        VocabCardData(front: 'uno', back: 'eins', vocabId: 1, verified: true),
        VocabCardData(front: 'dos', back: 'zwei', vocabId: 2, verified: false),
      ]);
      final cards = await repo.watchCards(a).first;
      expect(cards.map((c) => (c.front, c.vocabId, c.verified)).skip(1), [
        ('uno', 1, true),
        ('dos', 2, false),
      ]);
    });
  });
}
