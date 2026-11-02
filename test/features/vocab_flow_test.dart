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

  Future<List<VocabCard>> cardsOf(int setId) =>
      (env.db.select(env.db.cards)
            ..where((c) => c.setId.equals(setId))
            ..orderBy([(c) => OrderingTerm.asc(c.position)]))
          .get();

  Finder fieldOf(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  /// Wartet die Entprellung der Hinweise ab.
  Future<void> settleAssist(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> openNewCard(WidgetTester tester, String setTitle) async {
    await env.pumpApp(tester);
    await tester.tap(find.text(setTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCard')));
    await tester.pumpAndSettle();
  }

  testWidgets('Wort aus der Vokabeldatenbank erkennen und übernehmen', (
    tester,
  ) async {
    final setId = await repo.createSet(title: 'Spanisch', language: 'es');
    await openNewCard(tester, 'Spanisch');

    await tester.enterText(fieldOf('frontField'), 'casas');
    await settleAssist(tester);
    expect(find.text('Schon in der Vokabeldatenbank'), findsWidgets);

    await tester.tap(find.byKey(const Key('adoptVocab')).first);
    await settleAssist(tester);
    expect(find.text('Mit der Vokabeldatenbank verknüpft'), findsOneWidget);
    final back = tester.widget<TextField>(fieldOf('backField'));
    expect(back.controller!.text, 'das Haus, das Zuhause');

    await tester.ensureVisible(find.byKey(const Key('saveCard')));
    await tester.tap(find.byKey(const Key('saveCard')));
    await tester.pumpAndSettle();

    final card = (await cardsOf(setId)).single;
    expect(card.front, 'la casa');
    expect(card.vocabId, isNotNull);
  });

  testWidgets('Manuelles Wort aus der Datenbank kann verworfen werden', (
    tester,
  ) async {
    final setId = await repo.createSet(title: 'Türkisch', language: 'tr');
    await openNewCard(tester, 'Türkisch');

    await tester.enterText(fieldOf('frontField'), 'ev');
    await tester.enterText(fieldOf('backField'), 'Haus');
    await settleAssist(tester);
    expect(find.text('Schon in der Vokabeldatenbank'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('discardBecauseInVocab')));
    await tester.tap(find.byKey(const Key('discardBecauseInVocab')));
    await tester.pumpAndSettle();

    expect(find.text('Karte verworfen'), findsOneWidget);
    expect(await cardsOf(setId), isEmpty);
  });

  testWidgets('Doppelte Karte im Set wird angezeigt und verworfen', (
    tester,
  ) async {
    final setId = await repo.createSet(title: 'Spanisch', language: 'es');
    await repo
        .createSet(title: 'Anderes', language: 'es')
        .then(
          (id) => repo.addCard(
            id,
            CardDraft(
              front: RichDocument.plain('mesa'),
              back: RichDocument.plain('Tisch'),
            ),
          ),
        );
    await repo.addCard(
      setId,
      CardDraft(
        front: RichDocument.plain('la mesa'),
        back: RichDocument.plain('der Tisch'),
      ),
    );
    await openNewCard(tester, 'Spanisch');

    await tester.enterText(fieldOf('frontField'), 'Mesa');
    await settleAssist(tester);
    expect(find.text('Schon in diesem Set'), findsOneWidget);
    // Duplikat-Hinweis und Datenbank-Treffer zeigen beide „la mesa – der Tisch“
    expect(find.text('la mesa – der Tisch'), findsWidgets);
    expect(find.text('Auch in: Anderes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discardDuplicate')));
    await tester.pumpAndSettle();
    expect(await cardsOf(setId), hasLength(1));
  });

  testWidgets('Vorschläge beim Tippen füllen die Karte', (tester) async {
    final setId = await repo.createSet(title: 'Spanisch', language: 'es');
    await openNewCard(tester, 'Spanisch');
    await tester.enterText(fieldOf('frontField'), 'perr');
    await settleAssist(tester);
    final chip = find.widgetWithText(ActionChip, 'el perro – der Hund');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await settleAssist(tester);
    await tester.ensureVisible(find.byKey(const Key('saveCard')));
    await tester.tap(find.byKey(const Key('saveCard')));
    await tester.pumpAndSettle();
    final card = (await cardsOf(setId)).single;
    expect(card.front, 'el perro');
    expect(card.back, 'der Hund');
  });

  testWidgets('Doppelte Karten im Set: Hinweis und Löschen', (tester) async {
    final setId = await repo.createSet(title: 'Spanisch', language: 'es');
    for (final f in ['el gato', 'gato']) {
      await repo.addCard(
        setId,
        CardDraft(
          front: RichDocument.plain(f),
          back: RichDocument.plain('Katze'),
        ),
      );
    }
    await env.pumpApp(tester);
    await tester.tap(find.text('Spanisch'));
    await tester.pumpAndSettle();
    expect(find.text('doppelt – löschen'), findsNWidgets(2));
    await tester.tap(find.text('doppelt – löschen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(await cardsOf(setId), hasLength(1));
    expect(find.text('doppelt – löschen'), findsNothing);
  });

  testWidgets('Vorgefertigtes Set aus der Datenbank anlegen', (tester) async {
    await env.pumpApp(tester);
    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createPreset')));
    await tester.pumpAndSettle();
    expect(find.text('Vorgefertigte Sets'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preset-A1-essen')));
    await tester.pumpAndSettle();
    expect(find.text('Spanisch A1 – Essen & Trinken'), findsOneWidget);
    await tester.tap(find.byKey(const Key('addPreset')));
    await tester.pumpAndSettle();

    final sets = await env.db.select(env.db.sets).get();
    expect(sets.single.title, 'Spanisch A1 – Essen & Trinken');
    final cards = await cardsOf(sets.single.id);
    expect(cards.length, greaterThan(20));
    expect(cards.every((c) => c.vocabId != null), isTrue);
    expect(cards.map((c) => c.front), contains('el pan'));
    expect(find.text('Spanisch A1 – Essen & Trinken'), findsWidgets);
  });

  testWidgets('Vorgefertigtes Set: Türkisch umschalten', (tester) async {
    await env.pumpApp(tester);
    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createPreset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇹🇷 Türkisch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preset-A1-alle')));
    await tester.pumpAndSettle();
    expect(find.text('Türkisch – Grundwortschatz A1'), findsOneWidget);
  });
}
