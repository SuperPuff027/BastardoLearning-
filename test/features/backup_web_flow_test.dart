import 'dart:typed_data';

import 'package:barstardo_learning/core/rich_text.dart';
import 'package:barstardo_learning/data/library_repository.dart';
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

  Future<void> openSettingsAt(WidgetTester tester, Key key) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Sicherung exportieren und wieder importieren', (tester) async {
    final setId = await repo.createSet(title: 'Gesichert', language: 'es');
    await repo.addCard(
      setId,
      CardDraft(
        front: RichDocument.plain('sí'),
        back: RichDocument.plain('ja'),
      ),
    );
    await env.pumpApp(tester);
    await openSettingsAt(tester, const Key('exportBackup'));

    await tester.tap(find.byKey(const Key('exportBackup')));
    await tester.pumpAndSettle();
    expect(env.savedBackup, isNotNull);
    expect(env.savedBackupName, startsWith('barstardo-sicherung-'));

    // Daten löschen, dann Sicherung einspielen
    await repo.deleteSet(setId);
    env.backupToOpen = env.savedBackup;
    await tester.tap(find.byKey(const Key('importBackup')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Sets und 1 Karten'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmRestore')));
    await tester.pumpAndSettle();
    expect(find.text('Wiederhergestellt: 1 Sets, 1 Karten'), findsOneWidget);
    final sets = await env.db.select(env.db.sets).get();
    expect(sets.single.title, 'Gesichert');
  });

  testWidgets('Ungültige Datei beim Import', (tester) async {
    await env.pumpApp(tester);
    await openSettingsAt(tester, const Key('importBackup'));
    env.backupToOpen = Uint8List.fromList('quatsch'.codeUnits);
    await tester.tap(find.byKey(const Key('importBackup')));
    await tester.pumpAndSettle();
    expect(find.text('Die Datei ist keine gültige Sicherung.'), findsOneWidget);
  });

  testWidgets('Browser-Version: Live-Text-Anleitung statt Kamera-Erkennung', (
    tester,
  ) async {
    env.webMode = true;
    await env.pumpApp(tester);
    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createScan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('liveTextHelp')), findsOneWidget);
    expect(find.byKey(const Key('scanCamera')), findsNothing);
    expect(find.text('Kopierten Text einfügen'), findsOneWidget);
  });

  testWidgets(
    'Browser-Version: keine Offline-Übersetzung in den Einstellungen',
    (tester) async {
      env.webMode = true;
      await env.pumpApp(tester);
      await openSettingsAt(tester, const Key('exportBackup'));
      expect(find.text('Offline-Übersetzung'), findsNothing);
    },
  );
}
