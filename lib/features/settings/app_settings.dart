import 'package:flutter/material.dart';

/// Abfragerichtung im Lernmodus.
enum QuizDirection {
  mixed('gemischt', 'Gemischt'),
  foreignToGerman('foreign_to_de', 'Fremdwort → Deutsch'),
  germanToForeign('de_to_foreign', 'Deutsch → Fremdwort');

  const QuizDirection(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static QuizDirection fromStorage(String? value) => QuizDirection.values
      .firstWhere((d) => d.storageValue == value, orElse: () => mixed);
}

/// Alle Einstellungen der App, unveränderlich.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.remindersEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 18, minute: 0),
    this.ttsEnabled = false,
    this.quizDirection = QuizDirection.mixed,
  });

  final ThemeMode themeMode;
  final bool remindersEnabled;
  final TimeOfDay reminderTime;

  /// Globaler TTS-Schalter. Ist er aus, liest die App nie vor,
  /// unabhängig von der Einstellung des Sets.
  final bool ttsEnabled;
  final QuizDirection quizDirection;

  static const keyThemeMode = 'theme_mode';
  static const keyRemindersEnabled = 'reminders_enabled';
  static const keyReminderTime = 'reminder_time';
  static const keyTtsEnabled = 'tts_enabled';
  static const keyQuizDirection = 'quiz_direction';

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? remindersEnabled,
    TimeOfDay? reminderTime,
    bool? ttsEnabled,
    QuizDirection? quizDirection,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderTime: reminderTime ?? this.reminderTime,
    ttsEnabled: ttsEnabled ?? this.ttsEnabled,
    quizDirection: quizDirection ?? this.quizDirection,
  );

  factory AppSettings.fromMap(Map<String, String> map) {
    const defaults = AppSettings();
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == map[keyThemeMode],
        orElse: () => defaults.themeMode,
      ),
      remindersEnabled:
          _parseBool(map[keyRemindersEnabled]) ?? defaults.remindersEnabled,
      reminderTime: _parseTime(map[keyReminderTime]) ?? defaults.reminderTime,
      ttsEnabled: _parseBool(map[keyTtsEnabled]) ?? defaults.ttsEnabled,
      quizDirection: QuizDirection.fromStorage(map[keyQuizDirection]),
    );
  }

  Map<String, String> toMap() => {
    keyThemeMode: themeMode.name,
    keyRemindersEnabled: remindersEnabled.toString(),
    keyReminderTime: formatTime(reminderTime),
    keyTtsEnabled: ttsEnabled.toString(),
    keyQuizDirection: quizDirection.storageValue,
  };

  static String formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static bool? _parseBool(String? v) => switch (v) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  static TimeOfDay? _parseTime(String? v) {
    if (v == null) return null;
    final parts = v.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.remindersEnabled == remindersEnabled &&
      other.reminderTime == reminderTime &&
      other.ttsEnabled == ttsEnabled &&
      other.quizDirection == quizDirection;

  @override
  int get hashCode => Object.hash(
    themeMode,
    remindersEnabled,
    reminderTime,
    ttsEnabled,
    quizDirection,
  );
}
