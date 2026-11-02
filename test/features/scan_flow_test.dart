import 'dart:io';

import 'package:barstardo_learning/data/database.dart';
import 'package:barstardo_learning/data/library_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late TestEnv env;
  late LibraryRepository repo;

  setUp(() async {
    env = await TestEnv.create();
    repo = LibraryRepository(env.db, env.media);
    env.pickedImage = File('${env.dir.path}/blatt.jpg')
      ..writeAsBytesSync([0, 1, 2]);
  });
  tearDown(() => env.dispose());

  Future<List<VocabCard>> cardsOf(int setId) =>
      (env.db.select(env.db.cards)
            ..where((c) => c.setId.equals(setId))
            ..orderBy([(c) => OrderingTerm.asc(c.position)]))
          .get();

  Future<void> openScanFromLibrary(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createScan')));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Handgeschriebenes Blatt: Paare übernehmen, neue Wörter aufnehmen '
    'und beim nächsten Mal wiedererkennen',
    (tester) async {
      env.ocr.lines = [
        'Vokabeln Lektion 3',
        'las casas – die Häuser',
        'el xilófono – das Xylofon',
        'comer = essen',
      ];
      await env.pumpApp(tester);
      await openScanFromLibrary(tester);

      await tester.tap(find.byKey(const Key('scanGallery')));
      await tester.pumpAndSettle();
      expect(find.text('Text prüfen'), findsOneWidget);
      expect(find.textContaining('el xilófono – das Xylofon'), findsOneWidget);

      await tester.tap(find.byKey(const Key('extractWords')));
      await tester.pumpAndSettle();
      expect(find.text('Wörter auswählen'), findsOneWidget);
      expect(find.text('la casa'), findsOneWidget);
      expect(find.text('die Häuser'), findsOneWidget);
      expect(find.text('el xilófono'), findsOneWidget);
      expect(find.textContaining('neu'), findsWidgets);

      await tester.enterText(find.byKey(const Key('scanTitle')), 'Lektion 3');
      await tester.tap(find.byKey(const Key('saveScan')));
      await tester.pumpAndSettle();

      final set = (await env.db.select(env.db.sets).get()).single;
      expect(set.title, 'Lektion 3');
      expect(set.language, 'es');
      final cards = await cardsOf(set.id);
      expect(cards.map((c) => c.front), ['la casa', 'el xilófono', 'comer']);
      final xilofono = cards[1];
      expect(xilofono.back, 'das Xylofon');
      expect(xilofono.vocabId, isNull); // neues Wort, nicht in der Datenbank
      expect(xilofono.verified, isFalse);
      expect(cards[0].vocabId, isNotNull);

      // Zweiter Scan: das aufgenommene Wort wird wiedererkannt
      await tester.tap(find.byIcon(Icons.collections_bookmark)); // aktiver Tab
      await tester.pumpAndSettle();
      env.ocr.lines = ['Mi hermano toca el xilófono.'];
      // Snackbar „… Karten angelegt“ abwarten (verdeckt sonst den Knopf)
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('libraryAdd')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('createScan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scanCamera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('extractWords')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('word-xilófono')));
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const Key('word-xilófono')),
      );
      expect(tile.value, isFalse); // schon vorhanden
      expect(find.textContaining('deine Karten'), findsWidgets);
    },
  );

  testWidgets(
    'Text einfügen ins vorhandene türkische Set (Suffixe → Grundform)',
    (tester) async {
      final setId = await repo.createSet(title: 'Türkisch', language: 'tr');
      await env.pumpApp(tester);
      await tester.tap(find.text('Türkisch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('emptyScan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scanText')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('scanInput')),
        'Evlerimizde büyük bir bahçe var.',
      );
      await tester.tap(find.byKey(const Key('extractWords')));
      await tester.pumpAndSettle();

      expect(find.text('ev'), findsOneWidget);
      expect(find.text('auf dem Blatt: Evlerimizde'), findsOneWidget);
      expect(find.text('bahçe'), findsOneWidget);
      expect(find.textContaining('Türkisch'), findsWidgets);
      await tester.tap(find.byKey(const Key('saveScan')));
      await tester.pumpAndSettle();

      final cards = await cardsOf(setId);
      expect(cards.map((c) => c.front), containsAll(['ev', 'büyük', 'bahçe']));
      expect(cards.map((c) => c.front), isNot(contains('bir'))); // Füllwort
      expect(find.text('Türkisch'), findsWidgets); // zurück im Set
    },
  );

  testWidgets('Fehlende Übersetzung: eintragen oder offline übersetzen', (
    tester,
  ) async {
    env.translation
      ..ready.add('es')
      ..dictionary['zanahoria'] = 'die Karotte';
    await env.pumpApp(tester);
    await openScanFromLibrary(tester);
    await tester.tap(find.byKey(const Key('scanText')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('scanInput')),
      'Compro una zanahoria y un xilófono.',
    );
    await tester.tap(find.byKey(const Key('extractWords')));
    await tester.pumpAndSettle();
    expect(find.text('Übersetzung fehlt'), findsNWidgets(2));

    // Speichern ist blockiert, solange Übersetzungen fehlen
    await tester.tap(find.byKey(const Key('saveScan')));
    await tester.pumpAndSettle();
    expect(find.text('2 Wörter haben noch keine Übersetzung'), findsOneWidget);

    await tester.tap(find.byKey(const Key('translateMissing')));
    await tester.pumpAndSettle();
    expect(find.text('die Karotte'), findsOneWidget);
    expect(find.textContaining('maschinell'), findsOneWidget);

    // Rest von Hand eintragen
    await scrollTo(tester, find.byKey(const Key('word-xilófono')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('word-xilófono')),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('editBack')), 'das Xylofon');
    await tester.tap(find.byKey(const Key('editSave')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveScan')));
    await tester.pumpAndSettle();
    final set = (await env.db.select(env.db.sets).get()).single;
    final cards = await cardsOf(set.id);
    expect(
      cards.map((c) => c.back),
      containsAll(['die Karotte', 'das Xylofon']),
    );
    expect(cards.firstWhere((c) => c.back == 'die Karotte').verified, isFalse);
  });

  testWidgets('Kein Text auf dem Foto', (tester) async {
    env.ocr.lines = [];
    await env.pumpApp(tester);
    await openScanFromLibrary(tester);
    await tester.tap(find.byKey(const Key('scanGallery')));
    await tester.pumpAndSettle();
    expect(find.text('Auf dem Bild wurde kein Text erkannt.'), findsOneWidget);
    expect(find.text('Karten aus Foto oder Text'), findsOneWidget);
  });

  testWidgets('Einstellungen: Übersetzungsmodell laden und löschen', (
    tester,
  ) async {
    await env.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('translationModel-es'));
    await scrollTo(tester, tile);
    expect(
      find.descendant(of: tile, matching: find.text('Nicht geladen')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.download_outlined)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laden'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: tile,
        matching: find.text('Geladen – übersetzt offline'),
      ),
      findsOneWidget,
    );
    expect(env.translation.ready, contains('es'));
    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.delete_outline)),
    );
    await tester.pumpAndSettle();
    expect(env.translation.ready, isEmpty);
  });
}
