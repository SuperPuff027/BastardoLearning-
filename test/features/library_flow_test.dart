import 'dart:io';

import 'package:barstardo_learning/core/rich_text.dart';
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
  });
  tearDown(() => env.dispose());

  // Hinweis: In Widget-Tests keine Drift-Streams (`.first`) awaiten, das
  // hängt unter Fake-Async beim Abbau. Daher direkte Abfragen.
  Future<List<VocabCard>> cardsOf(int setId) =>
      (env.db.select(env.db.cards)
            ..where((c) => c.setId.equals(setId))
            ..orderBy([(c) => OrderingTerm.asc(c.position)]))
          .get();
  Future<List<VocabSet>> allSets() => env.db.select(env.db.sets).get();

  Future<void> openNewSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
  }

  Future<void> enterCard(WidgetTester tester, String front, String back) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('frontField')),
        matching: find.byType(TextField),
      ),
      front,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('backField')),
        matching: find.byType(TextField),
      ),
      back,
    );
  }

  testWidgets('Ordner anlegen, darin Set anlegen, Karten hinzufügen', (
    tester,
  ) async {
    await env.pumpApp(tester);

    await openNewSheet(tester);
    await tester.tap(find.text('Neuer Ordner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameDialogField')), 'Schule');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Schule'), findsOneWidget);
    expect(find.text('0 Sets'), findsOneWidget);

    await tester.tap(find.text('Schule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neues Set'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('setTitle')),
      'Türkisch Basics',
    );
    await tester.tap(find.text('🇹🇷 Türkisch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveSet')));
    await tester.pumpAndSettle();

    // Set-Detailseite
    expect(find.text('Türkisch Basics'), findsOneWidget);
    expect(find.text('Noch keine Karten in diesem Set.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addCard')));
    await tester.pumpAndSettle();
    expect(find.text('Vorderseite (Türkisch)'), findsOneWidget);

    await enterCard(tester, 'ev', 'Haus');
    await tester.tap(find.byKey(const Key('saveCardNext')));
    await tester.pumpAndSettle();
    expect(find.text('Neue Karte (2)'), findsOneWidget);

    await enterCard(tester, 'su', 'Wasser');
    await tester.tap(find.byKey(const Key('saveCard')));
    await tester.pumpAndSettle();

    expect(find.text('ev'), findsOneWidget);
    expect(find.text('Wasser'), findsOneWidget);

    final sets = await allSets();
    expect(sets.single.language, 'tr');
    expect(sets.single.folderId, isNotNull);
    expect(await cardsOf(sets.single.id), hasLength(2));
  });

  testWidgets('leere Karte wird nicht gespeichert', (tester) async {
    final setId = await repo.createSet(title: 'S', language: 'es');
    await env.pumpApp(tester);
    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCard')));
    await tester.pumpAndSettle();
    await enterCard(tester, 'hola', '   ');
    await tester.tap(find.byKey(const Key('saveCard')));
    await tester.pumpAndSettle();
    expect(find.text('Die Rückseite darf nicht leer sein'), findsOneWidget);
    expect(await cardsOf(setId), isEmpty);
  });

  testWidgets('Karten markieren und nur markierte anzeigen', (tester) async {
    final setId = await repo.createSet(title: 'Zahlen', language: 'es');
    final uno = await repo.addCard(
      setId,
      CardDraft(
        front: RichDocument.plain('uno'),
        back: RichDocument.plain('eins'),
      ),
    );
    await repo.addCard(
      setId,
      CardDraft(
        front: RichDocument.plain('dos'),
        back: RichDocument.plain('zwei'),
      ),
    );

    await env.pumpApp(tester);
    await tester.tap(find.text('Zahlen'));
    await tester.pumpAndSettle();
    expect(find.text('Nur markierte (0)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pumpAndSettle();
    expect(find.text('Nur markierte (1)'), findsOneWidget);
    expect((await repo.getCard(uno))!.starred, isTrue);

    await tester.tap(find.byKey(const Key('starredFilter')));
    await tester.pumpAndSettle();
    expect(find.text('uno'), findsOneWidget);
    expect(find.text('dos'), findsNothing);
  });

  testWidgets('Text-Import mit automatisch erkanntem Trennzeichen', (
    tester,
  ) async {
    final setId = await repo.createSet(title: 'Import', language: 'es');
    await env.pumpApp(tester);
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text importieren'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('importInput')),
      'la casa; das Haus\ncomer; essen\nkaputt',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Nicht lesbar (Zeile 3): kein Trennzeichen oder leere Seite.'),
      findsOneWidget,
    );
    expect(find.text('2 Karten importieren'), findsOneWidget);

    await tester.tap(find.byKey(const Key('runImport')));
    await tester.pumpAndSettle();
    expect(find.text('2 Karten importiert'), findsOneWidget);
    expect(find.text('la casa'), findsOneWidget);
    final cards = await cardsOf(setId);
    expect(cards.map((c) => c.back), ['das Haus', 'essen']);
  });

  testWidgets('Fett-Formatierung wird gespeichert', (tester) async {
    final setId = await repo.createSet(title: 'Rich', language: 'es');
    await env.pumpApp(tester);
    await tester.tap(find.text('Rich'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCard')));
    await tester.pumpAndSettle();
    await enterCard(tester, 'la casa', 'das Haus');

    // „casa“ auswählen und fett machen
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('frontField')),
        matching: find.byType(TextField),
      ),
    );
    field.controller!.selection = const TextSelection(
      baseOffset: 3,
      extentOffset: 7,
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('frontField')),
        matching: find.byTooltip('Fett'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveCard')));
    await tester.pumpAndSettle();

    final card = (await cardsOf(setId)).single;
    expect(card.front, 'la casa');
    final doc = RichDocument.decode(card.front, card.frontRich);
    expect(doc.spans, const [
      RichSpan('la '),
      RichSpan('casa', RichStyle(bold: true)),
    ]);
  });

  testWidgets('Bild aus der Galerie wird lokal gespeichert', (tester) async {
    final setId = await repo.createSet(title: 'Bilder', language: 'es');
    final src = File('${env.dir.path}/pick.jpg')..writeAsBytesSync([1, 2, 3]);
    env.pickedImage = src;

    await env.pumpApp(tester);
    await tester.tap(find.text('Bilder'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCard')));
    await tester.pumpAndSettle();
    await enterCard(tester, 'el perro', 'der Hund');
    await tester.tap(find.text('Aus Galerie'));
    await settleIo(tester);
    expect(find.text('Bild entfernen'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveCard')));
    await tester.pumpAndSettle();

    final card = (await cardsOf(setId)).single;
    expect(card.imagePath, startsWith('images/'));
    expect(env.media.resolve(card.imagePath!).existsSync(), isTrue);
  });

  testWidgets('Set kopieren über das Menü', (tester) async {
    final setId = await repo.createSet(title: 'Original', language: 'es');
    await repo.addCard(
      setId,
      CardDraft(
        front: RichDocument.plain('sí'),
        back: RichDocument.plain('ja'),
      ),
    );
    await env.pumpApp(tester);
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopieren'));
    await tester.pumpAndSettle();

    expect(find.text('Original (Kopie)'), findsOneWidget);
    expect(find.text('sí'), findsOneWidget);
    expect(await allSets(), hasLength(2));
  });

  testWidgets('Sets zusammenführen über das Menü', (tester) async {
    final a = await repo.createSet(title: 'Ziel', language: 'es');
    final b = await repo.createSet(title: 'Quelle', language: 'es');
    await repo.createSet(title: 'Türkisch', language: 'tr');
    await repo.addCard(
      b,
      CardDraft(
        front: RichDocument.plain('dos'),
        back: RichDocument.plain('zwei'),
      ),
    );

    await env.pumpApp(tester);
    await tester.tap(find.text('Ziel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zusammenführen'));
    await tester.pumpAndSettle();

    // Nur Sets derselben Sprache werden angeboten
    expect(find.widgetWithText(CheckboxListTile, 'Türkisch'), findsNothing);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Quelle'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Zusammenführen'));
    await tester.pumpAndSettle();

    expect(find.text('1 Karte übernommen'), findsOneWidget);
    expect(find.text('dos'), findsOneWidget);
    expect(await cardsOf(a), hasLength(1));
    expect(await cardsOf(b), hasLength(1));
  });

  testWidgets('Set in Ordner verschieben', (tester) async {
    final setId = await repo.createSet(title: 'Lose', language: 'es');
    await env.pumpApp(tester);
    await tester.tap(find.text('Lose'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Ordner verschieben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neuer Ordner …'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameDialogField')), 'Urlaub');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    final set = await repo.getSet(setId);
    expect(set!.folderId, isNotNull);
    expect(find.text('Set verschoben'), findsOneWidget);
  });
}
