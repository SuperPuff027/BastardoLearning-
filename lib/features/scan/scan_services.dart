import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Texterkennung (OCR) auf dem Gerät.
abstract class TextRecognitionService {
  /// Erkannte Zeilen in Lesereihenfolge.
  Future<List<String>> recognizeLines(File image);
}

/// Spracherkennung auf dem Gerät.
abstract class LanguageIdService {
  /// Sprachcode → Konfidenz (0..1); leer, wenn unbestimmt.
  Future<Map<String, double>> identify(String text);
}

/// Übersetzung auf dem Gerät (Sprachmodelle einmalig herunterladen).
abstract class TranslationService {
  /// Sind die Modelle für [language] ↔ Deutsch vorhanden?
  Future<bool> isReady(String language);

  /// Lädt die Modelle für [language] und Deutsch (einmalig, ~30 MB je Sprache).
  Future<bool> download(String language, {bool wifiOnly = true});

  /// Löscht das Modell für [language] (Deutsch bleibt, solange noch nötig).
  Future<void> delete(String language);

  /// Übersetzt [text] aus [language] ins Deutsche; `null` bei Fehler.
  Future<String?> translate(String language, String text);
}

class MlKitTextRecognition implements TextRecognitionService {
  @override
  Future<List<String>> recognizeLines(File image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(image.path),
      );
      return [
        for (final block in result.blocks)
          for (final line in block.lines) line.text,
      ];
    } finally {
      await recognizer.close();
    }
  }
}

class MlKitLanguageId implements LanguageIdService {
  @override
  Future<Map<String, double>> identify(String text) async {
    final id = LanguageIdentifier(confidenceThreshold: 0.2);
    try {
      final langs = await id.identifyPossibleLanguages(text);
      return {
        for (final l in langs)
          if (l.languageTag != 'und') l.languageTag: l.confidence,
      };
    } finally {
      await id.close();
    }
  }
}

class MlKitTranslation implements TranslationService {
  final _models = OnDeviceTranslatorModelManager();

  static TranslateLanguage? _lang(String code) => switch (code) {
    'es' => TranslateLanguage.spanish,
    'tr' => TranslateLanguage.turkish,
    'de' => TranslateLanguage.german,
    _ => null,
  };

  @override
  Future<bool> isReady(String language) async {
    final source = _lang(language);
    if (source == null) return false;
    return await _models.isModelDownloaded(source.bcpCode) &&
        await _models.isModelDownloaded(TranslateLanguage.german.bcpCode);
  }

  @override
  Future<bool> download(String language, {bool wifiOnly = true}) async {
    final source = _lang(language);
    if (source == null) return false;
    final de = await _models.downloadModel(
      TranslateLanguage.german.bcpCode,
      isWifiRequired: wifiOnly,
    );
    final src = await _models.downloadModel(
      source.bcpCode,
      isWifiRequired: wifiOnly,
    );
    return de && src;
  }

  @override
  Future<void> delete(String language) async {
    final source = _lang(language);
    if (source == null) return;
    await _models.deleteModel(source.bcpCode);
    final others = ['es', 'tr'].where((l) => l != language);
    var germanNeeded = false;
    for (final o in others) {
      if (await _models.isModelDownloaded(_lang(o)!.bcpCode)) {
        germanNeeded = true;
      }
    }
    if (!germanNeeded) {
      await _models.deleteModel(TranslateLanguage.german.bcpCode);
    }
  }

  @override
  Future<String?> translate(String language, String text) async {
    final source = _lang(language);
    if (source == null || !await isReady(language)) return null;
    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: TranslateLanguage.german,
    );
    try {
      final result = await translator.translateText(text);
      return result.trim().isEmpty ? null : result.trim();
    } catch (_) {
      return null;
    } finally {
      await translator.close();
    }
  }
}

final textRecognitionProvider = Provider<TextRecognitionService>(
  (ref) => MlKitTextRecognition(),
);

final languageIdProvider = Provider<LanguageIdService>(
  (ref) => MlKitLanguageId(),
);

final translationProvider = Provider<TranslationService>(
  (ref) => MlKitTranslation(),
);
