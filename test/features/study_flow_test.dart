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

  Future<int> setWith(
    Map<String, String> pairs, {
    String title = 'Zahlen',
  }) async {
    final id = await repo.createSet(title: title, language: 'es');
    for (final e in pairs.entries) {
      await repo.addCard(
        id,
        CardDraft(
          front: RichDocument.plain(e.key),
          back: RichDocument.plain(e.value),
        ),
      );
    }
    return id;
  }

  Future<List<ReviewLog>> logs() => env.db.select(env.db.reviewLogs).get();
  Future<List<ReviewState>> states() =>
      env.db.select(env.db.reviewStates).get();

  /// Öffnet das Set und startet einen Modus mit Richtung Fremd → DE.
  Future<void> startMode(
    WidgetTester tester,
    String setTitle,
    String modeKey,
  ) async {
    await env.pumpApp(tester);
    await tester.tap(find.text(setTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(modeKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fremd → DE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('startStudy')));
    await tester.pumpAndSettle();
  }

  const pairs = {'uno': 'eins', 'dos': 'zwei', 'tres': 'drei'};

  String? visiblePrompt(WidgetTester tester) {
    for (final p in pairs.keys) {
      if (find.text(p).evaluate().isNotEmpty) return p;
    }
    return null;
  }

  testWidgets(
    'Karteikarten: umdrehen, gewusst/nicht gewusst, Zusammenfassung',
    (tester) async {
      await setWith({'uno': 'eins', 'dos': 'zwei'});
      await startMode(tester, 'Zahlen', 'mode-flashcards');

      expect(find.text('Karte 1 von 2'), findsOneWidget);
      final prompt = visiblePrompt(tester)!;
      await tester.tap(find.byKey(const Key('flashcard')));
      await tester.pumpAndSettle();
      expect(find.text(pairs[prompt]!), findsOneWidget);

      await tester.tap(find.byKey(const Key('knownButton')));
      await tester.pumpAndSettle();
      expect(find.text('Karte 2 von 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unknownButton')));
      await tester.pumpAndSettle();

      expect(find.text('Runde geschafft!'), findsOneWidget);
      expect(find.text('Gewusst: 1'), findsOneWidget);
      expect(find.text('Nicht gewusste wiederholen (1)'), findsOneWidget);

      final l = await logs();
      expect(l, hasLength(2));
      expect(l.map((x) => x.mode).toSet(), {'flashcards'});
      expect(l.where((x) => x.correct), hasLength(1));
      expect(await states(), hasLength(2));

      await tester.tap(find.byKey(const Key('retryButton')));
      await tester.pumpAndSettle();
      expect(find.text('Karte 1 von 1'), findsOneWidget);
    },
  );

  testWidgets('Schreiben: smarte Bewertung und „Ich hatte recht“', (
    tester,
  ) async {
    await setWith({'uno': 'eins', 'dos': 'zwei'});
    await startMode(tester, 'Zahlen', 'mode-write');

    // erste Frage richtig (Groß/Klein egal)
    var prompt = visiblePrompt(tester)!;
    await tester.enterText(
      find.byKey(const Key('answerInput')),
      pairs[prompt]!.toUpperCase(),
    );
    await tester.tap(find.byKey(const Key('checkAnswer')));
    await tester.pumpAndSettle();
    expect(find.text('Richtig'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nextQuestion')));
    await tester.pumpAndSettle();

    // zweite Frage falsch, dann überstimmen
    prompt = visiblePrompt(tester)!;
    await tester.enterText(find.byKey(const Key('answerInput')), 'quatsch');
    await tester.tap(find.byKey(const Key('checkAnswer')));
    await tester.pumpAndSettle();
    expect(find.text('Falsch'), findsOneWidget);
    expect(find.text(pairs[prompt]!), findsOneWidget);
    await tester.tap(find.byKey(const Key('overrideAnswer')));
    await tester.pumpAndSettle();
    expect(find.text('Als richtig gewertet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nextQuestion')));
    await tester.pumpAndSettle();

    expect(find.text('2 von 2 richtig'), findsOneWidget);
    final l = await logs();
    expect(l.every((x) => x.correct), isTrue);
    expect(l.map((x) => x.rating), [3, 3]);
  });

  testWidgets('Schreiben: fehlender Akzent ist fast richtig', (tester) async {
    await setWith({'el niño': 'das Kind'}, title: 'Akzente');
    await env.pumpApp(tester);
    await tester.tap(find.text('Akzente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode-write')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DE → Fremd'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('startStudy')));
    await tester.pumpAndSettle();

    expect(find.text('das Kind'), findsOneWidget);
    // Sonderzeichen-Leiste für Spanisch
    expect(find.widgetWithText(ActionChip, 'ñ'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('answerInput')), 'nino');
    await tester.tap(find.byKey(const Key('checkAnswer')));
    await tester.pumpAndSettle();
    expect(find.text('Fast richtig'), findsOneWidget);
    expect(
      find.text('Achte auf die Akzente bzw. Sonderzeichen.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('nextQuestion')));
    await tester.pumpAndSettle();
    final l = await logs();
    expect(l.single.correct, isTrue);
    expect(l.single.rating, 2); // Schwer
  });

  testWidgets(
    'Lernmodus: Multiple Choice, dann Schreiben, bis alles gemeistert',
    (tester) async {
      await setWith({'uno': 'eins', 'dos': 'zwei'});
      await startMode(tester, 'Zahlen', 'mode-learn');

      var mcSeen = 0;
      var writtenSeen = 0;
      for (var i = 0; i < 10; i++) {
        if (find.text('Alle 2 Karten gemeistert!').evaluate().isNotEmpty) break;
        final prompt = visiblePrompt(tester)!;
        final answer = pairs[prompt]!;
        if (find.byKey(const Key('answerInput')).evaluate().isNotEmpty) {
          writtenSeen++;
          await tester.enterText(find.byKey(const Key('answerInput')), answer);
          await tester.tap(find.byKey(const Key('checkAnswer')));
        } else {
          mcSeen++;
          await tester.tap(find.widgetWithText(OutlinedButton, answer));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nextQuestion')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Alle 2 Karten gemeistert!'), findsOneWidget);
      expect(find.text('Ohne einen einzigen Fehler.'), findsOneWidget);
      expect(mcSeen, 2);
      expect(writtenSeen, 2);
      expect(await logs(), hasLength(4));
    },
  );

  testWidgets('Test: nur Freitext, alle richtig → 100 %', (tester) async {
    await setWith(pairs);
    await env.pumpApp(tester);
    await tester.tap(find.text('Zahlen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode-test')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fremd → DE'));
    for (final t in ['Multiple Choice', 'Wahr/Falsch', 'Zuordnen']) {
      await tester.tap(find.widgetWithText(FilterChip, t));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('startStudy')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      final card = find.byKey(Key('question-$i'));
      await tester.ensureVisible(card);
      final prompt = pairs.keys.firstWhere(
        (p) => find
            .descendant(of: card, matching: find.text(p))
            .evaluate()
            .isNotEmpty,
      );
      await tester.enterText(
        find.descendant(of: card, matching: find.byType(TextField)),
        pairs[prompt]!,
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Abgeben (3/3)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('submitTest')));
    await tester.pumpAndSettle();
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('3 von 3 Punkten'), findsOneWidget);
    expect((await logs()).map((l) => l.mode).toSet(), {'test'});
  });

  testWidgets('Test: unbeantwortet abgeben fragt nach', (tester) async {
    await setWith(pairs);
    await startMode(tester, 'Zahlen', 'mode-test');
    await tester.tap(find.byKey(const Key('submitTest')));
    await tester.pumpAndSettle();
    expect(find.text('Test abgeben?'), findsOneWidget);
    await tester.tap(find.text('Abgeben').last);
    await tester.pumpAndSettle();
    expect(find.text('0 %'), findsOneWidget);
  });

  testWidgets('Wiederholen: neue Karte lernen und bewerten', (tester) async {
    final setId = await setWith({'uno': 'eins'});
    await env.pumpApp(tester);
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('0 fällig · 1 neu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reviewAll')));
    await tester.pumpAndSettle();
    expect(find.text('Neue Karte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('revealAnswer')));
    await tester.pumpAndSettle();
    expect(find.text('3 T.'), findsOneWidget); // Vorschau für „Gut“
    await tester.tap(find.byKey(const Key('rate-good')));
    await tester.pumpAndSettle();
    expect(find.text('Wiederholung abgeschlossen'), findsOneWidget);
    expect(find.text('1 Karte wiederholt'), findsOneWidget);

    final s = (await states()).single;
    expect(s.reps, 1);
    expect(s.due.isAfter(DateTime.now().add(const Duration(days: 2))), isTrue);

    await tester.tap(find.byKey(const Key('doneButton')));
    await tester.pumpAndSettle();
    // Set ohne Fälliges wird ausgeblendet
    expect(find.text('Nichts fällig'), findsOneWidget);
    expect(setId, isPositive);
  });

  testWidgets('Wiederholen: „Nochmal“ bringt die Karte erneut', (tester) async {
    await setWith({'uno': 'eins'});
    await env.pumpApp(tester);
    await tester.tap(find.text('Zahlen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('revealAnswer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rate-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('revealAnswer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('revealAnswer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rate-easy')));
    await tester.pumpAndSettle();
    expect(find.text('Nochmal: 1'), findsOneWidget);
    expect(find.text('Leicht: 1'), findsOneWidget);
    final s = (await states()).single;
    expect(s.reps, 2);
    expect(s.lapses, 1);
  });

  testWidgets('Nur markierte Karten: Option im Startblatt', (tester) async {
    final id = await setWith(pairs);
    final dos =
        (await (env.db.select(env.db.cards)
                  ..where((c) => c.setId.equals(id) & c.front.equals('dos')))
                .getSingle())
            .id;
    await repo.setStarred(dos, true);
    await env.pumpApp(tester);
    await tester.tap(find.text('Zahlen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode-flashcards')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fremd → DE'));
    await tester.tap(find.byKey(const Key('optionStarred')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('startStudy')));
    await tester.pumpAndSettle();
    expect(find.text('Karte 1 von 1'), findsOneWidget);
    expect(find.text('dos'), findsOneWidget);
  });
}
