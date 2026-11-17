import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/platform/platform_services.dart';
import 'app/providers.dart';
import 'data/course_installer.dart';
import 'data/database.dart';
import 'data/library_repository.dart';
import 'features/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final settings = AppSettings.fromMap(await db.readAllSettings());
  final services = await createPlatformServices(db);
  // Kursordner (Aula 3, Türkisch I + II, Niveau-Ordner) beim ersten Start
  // anlegen. Fehler dürfen den Start nicht verhindern.
  try {
    await CourseInstaller(
      db,
      LibraryRepository(db, services.media),
      services.vocab,
    ).installNew();
  } catch (e, st) {
    debugPrint('Kursordner konnten nicht angelegt werden: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
        mediaStoreProvider.overrideWithValue(services.media),
        vocabRepositoryProvider.overrideWithValue(services.vocab),
      ],
      child: const BarstardoApp(),
    ),
  );
}
