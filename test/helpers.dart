import 'dart:io';
import 'dart:math';
import 'dart:ui' show Size;

import 'package:barstardo_learning/app/app.dart';
import 'package:barstardo_learning/app/providers.dart';
import 'package:barstardo_learning/data/database.dart';
import 'package:barstardo_learning/data/media/media_store.dart';
import 'package:barstardo_learning/data/vocab/vocab_repository.dart';
import 'package:barstardo_learning/features/scan/scan_services.dart';
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

  final ocr = FakeTextRecognition();
  final translation = FakeTranslation();

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
          vocabRepositoryProvider.overrideWithValue(sharedVocab),
          textRecognitionProvider.overrideWithValue(ocr),
          languageIdProvider.overrideWithValue(FakeLanguageId()),
          translationProvider.overrideWithValue(translation),
        ],
        child: const BarstardoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Mitgelieferte Vokabeldatenbank, einmal pro Testlauf geöffnet.
final VocabRepository sharedVocab = VocabRepository.open(
  VocabRepository.assetPath,
);

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

class FakeTextRecognition implements TextRecognitionService {
  List<String> lines = [];

  @override
  Future<List<String>> recognizeLines(File image) async => lines;
}

class FakeLanguageId implements LanguageIdService {
  @override
  Future<Map<String, double>> identify(String text) async => const {};
}

class FakeTranslation implements TranslationService {
  final ready = <String>{};
  final dictionary = <String, String>{};

  @override
  Future<bool> isReady(String language) async => ready.contains(language);

  @override
  Future<bool> download(String language, {bool wifiOnly = true}) async {
    ready.add(language);
    return true;
  }

  @override
  Future<void> delete(String language) async => ready.remove(language);

  @override
  Future<String?> translate(String language, String text) async =>
      ready.contains(language) ? dictionary[text] : null;
}
