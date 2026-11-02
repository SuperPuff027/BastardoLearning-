import 'package:barstardo_learning/features/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  Future<void> pumpApp(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) => env.pumpApp(tester, settings: settings);

  ThemeMode currentThemeMode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  testWidgets('startet auf „Meine Sets“ mit deutscher Navigation', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Meine Sets'), findsOneWidget);
    for (final label in ['Sets', 'Lernen', 'Fortschritt', 'Einstellungen']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Navigation zwischen den Tabs', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Nichts fällig'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Statistik'), findsOneWidget);
  });

  testWidgets('Dark Mode umschalten wird angewendet und gespeichert', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(currentThemeMode(tester), ThemeMode.system);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();

    expect(currentThemeMode(tester), ThemeMode.dark);
    expect(
      await tester.runAsync(() => env.db.readSetting('theme_mode')),
      'dark',
    );

    await tester.tap(find.text('Hell'));
    await tester.pumpAndSettle();
    expect(currentThemeMode(tester), ThemeMode.light);
  });

  testWidgets('gespeichertes Theme wird beim Start übernommen', (tester) async {
    await pumpApp(
      tester,
      settings: const AppSettings(themeMode: ThemeMode.dark),
    );
    expect(currentThemeMode(tester), ThemeMode.dark);
  });

  testWidgets('TTS und Erinnerungen sind abschaltbar', (tester) async {
    await pumpApp(
      tester,
      settings: const AppSettings(ttsEnabled: true, remindersEnabled: true),
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('ttsSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ttsSwitch')));
    await tester.pumpAndSettle();
    final tts = tester.widget<SwitchListTile>(
      find.byKey(const Key('ttsSwitch')),
    );

    await tester.ensureVisible(find.byKey(const Key('reminderTimeTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remindersSwitch')));
    await tester.pumpAndSettle();
    final rem = tester.widget<SwitchListTile>(
      find.byKey(const Key('remindersSwitch')),
    );
    expect(tts.value, isFalse);
    expect(rem.value, isFalse);
    final stored = await tester.runAsync(() => env.db.readAllSettings());
    expect(stored!['tts_enabled'], 'false');
    expect(stored['reminders_enabled'], 'false');

    final timeTile = tester.widget<ListTile>(
      find.byKey(const Key('reminderTimeTile')),
    );
    expect(timeTile.enabled, isFalse);
  });
}
