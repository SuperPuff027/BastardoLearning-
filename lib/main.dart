import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/database.dart';
import 'features/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final settings = AppSettings.fromMap(await db.readAllSettings());

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const BarstardoApp(),
    ),
  );
}
