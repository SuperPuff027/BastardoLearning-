import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/database.dart';
import 'data/media/media_store.dart';
import 'features/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final settings = AppSettings.fromMap(await db.readAllSettings());
  final docs = await getApplicationDocumentsDirectory();
  final media = MediaStore(Directory(p.join(docs.path, 'media')));

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
        mediaStoreProvider.overrideWithValue(media),
      ],
      child: const BarstardoApp(),
    ),
  );
}
