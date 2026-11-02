import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';
import '../data/library_repository.dart';
import '../data/media/media_store.dart';
import '../features/settings/app_settings.dart';

/// Die lokale Datenbank. Wird in `main()` überschrieben.
final databaseProvider = Provider<AppDatabase>(
  (ref) =>
      throw UnimplementedError('databaseProvider muss überschrieben werden'),
);

/// Beim Start geladene Einstellungen. Wird in `main()` überschrieben.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> _update(AppSettings next) async {
    state = next;
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      for (final e in next.toMap().entries) {
        await db.writeSetting(e.key, e.value);
      }
    });
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setRemindersEnabled(bool enabled) =>
      _update(state.copyWith(remindersEnabled: enabled));

  Future<void> setReminderTime(TimeOfDay time) =>
      _update(state.copyWith(reminderTime: time));

  Future<void> setTtsEnabled(bool enabled) =>
      _update(state.copyWith(ttsEnabled: enabled));

  Future<void> setQuizDirection(QuizDirection direction) =>
      _update(state.copyWith(quizDirection: direction));
}

/// Ablage für Bilder und Aufnahmen. Wird in `main()` überschrieben.
final mediaStoreProvider = Provider<MediaStore>(
  (ref) =>
      throw UnimplementedError('mediaStoreProvider muss überschrieben werden'),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(databaseProvider),
    ref.watch(mediaStoreProvider),
  ),
);

/// Bildauswahl (Kamera/Galerie). In Tests überschreibbar.
typedef ImagePickFn = Future<File?> Function(ImageSource source);

final imagePickerProvider = Provider<ImagePickFn>((ref) {
  final picker = ImagePicker();
  return (source) async {
    final x = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return x == null ? null : File(x.path);
  };
});
