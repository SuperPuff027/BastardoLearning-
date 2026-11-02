import 'dart:io';
import 'dart:math';
import 'dart:ui' show Size;

import 'package:barstardo_learning/app/app.dart';
import 'package:barstardo_learning/app/providers.dart';
import 'package:barstardo_learning/data/database.dart';
import 'package:barstardo_learning/data/media/media_store.dart';
import 'package:barstardo_learning/features/settings/app_settings.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testumgebung mit In-Memory-Datenbank und temporärem Medienordner.
class TestEnv {
  TestEnv._(this.db, this.dir, this.media);

  static Future<TestEnv> create() async {
    // Jeder Test hat seine eigene In-Memory-DB; die Warnung ist hier unnötig.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final dir = Directory.systemTemp.createTempSync('barstardo_widget');
    return TestEnv._(db, dir, MediaStore(dir));
  }

  final AppDatabase db;
  final Directory dir;
  final MediaStore media;

  /// Datei, die der Fake-Bildwähler zurückgibt (null = Abbruch).
  File? pickedImage;

  Future<void> dispose() async {
    // Nach einem fehlgeschlagenen Widget-Test kann close() auf noch offene
    // Stream-Abfragen warten; der Timeout verhindert, dass der Lauf hängt.
    await db.close().timeout(const Duration(seconds: 2), onTimeout: () {});
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
  }) async {
    // Handy-Format (400 × 900 logische Pixel)
    tester.view.physicalSize = const Size(1200, 2700);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(settings),
          mediaStoreProvider.overrideWithValue(media),
          imagePickerProvider.overrideWithValue((_) async => pickedImage),
          randomProvider.overrideWithValue(Random(42)),
        ],
        child: const BarstardoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Lässt echte Datei-I/O laufen. Jeder I/O-Schritt braucht eine echte
/// Event-Loop-Runde, daher mehrere Durchläufe mit Pump dazwischen.
Future<void> settleIo(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
