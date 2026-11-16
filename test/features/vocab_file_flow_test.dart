import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  testWidgets('Vokabeldatei importieren: Ordner mit Sets pro Lektion', (
    tester,
  ) async {
    env.vocabFileToPick = (
      name: 'aula3_wortschatz.csv',
      bytes: utf8.encode(
        'spanisch;deutsch;lektion\n'
        'el aeropuerto;Flughafen;Unidad 4\n'
        'abierto/a;offen;Unidad 2\n'
        'aparcar;parken;Unidad 4\n',
      ),
    );
    await env.pumpApp(tester);
    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createFromFile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickVocabFile')));
    await tester.pumpAndSettle();

    expect(find.text('3 Karten in 2 Sets'), findsOneWidget);
    expect(find.text('Unidad 2'), findsOneWidget);
    expect(find.text('Unidad 4'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('vocabFileFolder')),
      'Aula Internacional 3',
    );
    await tester.tap(find.byKey(const Key('runFileImport')));
    await tester.pumpAndSettle();

    expect(find.text('Aula Internacional 3'), findsWidgets);
    expect(find.text('Unidad 4'), findsOneWidget);
    final sets = await env.db.select(env.db.sets).get();
    expect(sets.map((s) => s.title).toSet(), {'Unidad 2', 'Unidad 4'});
    expect((await env.db.select(env.db.cards).get()), hasLength(3));
  });

  testWidgets('Türkische Datei: Sprache wird aus der Kopfzeile übernommen', (
    tester,
  ) async {
    env.vocabFileToPick = (
      name: 'tuerkisch.csv',
      bytes: utf8.encode(
        'türkisch;deutsch;lektion\n'
        '(+İ) açmak;… öffnen;Wörter A\n'
        'Açım.;Ich habe Hunger.;Sätze & Wendungen A–H\n',
      ),
    );
    await env.pumpApp(tester);
    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createFromFile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickVocabFile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runFileImport')));
    await tester.pumpAndSettle();
    final sets = await env.db.select(env.db.sets).get();
    expect(sets.map((s) => s.language).toSet(), {'tr'});
    expect(sets, hasLength(2));
  });
}
