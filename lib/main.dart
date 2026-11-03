import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/platform/platform_services.dart';
import 'app/providers.dart';
import 'data/database.dart';
import 'features/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final settings = AppSettings.fromMap(await db.readAllSettings());
  final services = await createPlatformServices(db);

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
