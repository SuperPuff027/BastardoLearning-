import 'package:barstardo_learning/features/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test(
      'Standardwerte: System-Theme, Erinnerungen aus, TTS aus, gemischt',
      () {
        const s = AppSettings();
        expect(s.themeMode, ThemeMode.system);
        expect(s.remindersEnabled, isFalse);
        expect(s.ttsEnabled, isFalse);
        expect(s.quizDirection, QuizDirection.mixed);
        expect(s.reminderTime, const TimeOfDay(hour: 18, minute: 0));
      },
    );

    test('leere Map ergibt Standardwerte', () {
      expect(AppSettings.fromMap({}), const AppSettings());
    });

    test('Roundtrip über toMap/fromMap', () {
      const s = AppSettings(
        themeMode: ThemeMode.dark,
        remindersEnabled: true,
        reminderTime: TimeOfDay(hour: 7, minute: 5),
        ttsEnabled: true,
        quizDirection: QuizDirection.germanToForeign,
      );
      expect(s.toMap()[AppSettings.keyReminderTime], '07:05');
      expect(AppSettings.fromMap(s.toMap()), s);
    });

    test('ungültige Werte fallen auf Standard zurück', () {
      final s = AppSettings.fromMap({
        AppSettings.keyThemeMode: 'lila',
        AppSettings.keyRemindersEnabled: 'vielleicht',
        AppSettings.keyReminderTime: '25:99',
        AppSettings.keyTtsEnabled: '1',
        AppSettings.keyQuizDirection: 'rückwärts',
      });
      expect(s, const AppSettings());
    });
  });
}
