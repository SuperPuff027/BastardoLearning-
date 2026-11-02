import '../../data/vocab/vocab_entry.dart';
import '../../data/vocab/vocab_repository.dart' show normalizeKey;
import 'language_guess.dart';
import 'lemmatizer.dart';

/// Woher die Übersetzung eines erkannten Wortes stammt.
enum TranslationSource {
  /// Vom Blatt („casa – Haus“).
  sheet('vom Blatt'),

  /// Aus einer eigenen, früher angelegten Karte („aufgenommen“).
  myCards('deine Karten'),

  /// Mitgelieferte Vokabeldatenbank.
  vocabDb('Datenbank'),

  /// On-device-Übersetzung (unbestätigt).
  machine('maschinell'),

  /// Keine Übersetzung gefunden – bitte eintragen.
  none('fehlt');

  const TranslationSource(this.label);
  final String label;
}

/// Ein erkanntes Wort/Paar für die Vorschau-Liste.
class ExtractedWord {
  ExtractedWord({
    required this.surface,
    required this.front,
    required this.back,
    required this.source,
    this.entry,
    this.selected = true,
    this.alreadyInCards = false,
    this.isNoise = false,
    this.example,
    this.count = 1,
  });

  /// Form, wie sie auf dem Blatt stand.
  final String surface;

  /// Vorderseite (Grundform, bei spanischen Nomen mit Artikel).
  String front;

  /// Rückseite (Deutsch), kann leer sein.
  String back;
  TranslationSource source;

  /// Datenbank-Eintrag, falls gefunden.
  final VocabEntry? entry;
  bool selected;

  /// Gibt es schon als Karte (dann standardmäßig nicht ausgewählt).
  final bool alreadyInCards;

  /// Zahl, Name oder Füllwort (standardmäßig nicht ausgewählt).
  final bool isNoise;

  /// Originalform als Beispiel, wenn sie von der Grundform abweicht.
  final String? example;
  int count;

  /// Wort steht nicht in der Datenbank → wird als neues Wort aufgenommen.
  bool get isNew => entry == null;

  /// Nur Datenbank-Einträge gelten als bestätigt (Brief Abschnitt 3).
  bool get verified =>
      source == TranslationSource.vocabDb && (entry?.verified ?? false);

  @override
  String toString() =>
      'ExtractedWord($surface → $front | $back, ${source.name}, sel=$selected)';
}

/// Ein Abschnitt einer Zeile mit erkannter Sprache.
class TextSegment {
  const TextSegment(this.text, this.language);

  final String text;
  final String? language;

  @override
  String toString() => 'TextSegment("$text", $language)';
}

/// Trennt „la casa – das Haus“, „ev = Haus“, „su: Wasser“ und Tabs.
final _segmentSplit = RegExp(r'\s+[-–—=→]+\s+|\s*:\s+|\t+|\s{3,}|\s*[=→]\s*');

const _articlesOnly = {
  'el',
  'la',
  'los',
  'las',
  'un',
  'una',
  'unos',
  'unas',
  'lo',
};

const _functionWords = {
  'es': {
    'de',
    'que',
    'y',
    'a',
    'en',
    'por',
    'con',
    'para',
    'del',
    'al',
    'se',
    'no',
    'mi',
    'tu',
    'su',
    'me',
    'te',
    'le',
    'o',
    'si',
    'pero',
    'como',
  },
  'tr': {'ve', 'de', 'da', 'mi', 'mı', 'mu', 'mü', 'ki', 'bir', 'bu', 'şu'},
};

/// Macht aus erkanntem Text (OCR oder eingefügt) Karteikarten-Vorschläge.
class WordExtractor {
  WordExtractor({
    required this.lemmatizer,
    required this.lookupForeign,
    required this.lookupGerman,
    this.myCards = const {},
  });

  final Lemmatizer lemmatizer;
  final VocabLookup lookupForeign;

  /// Deutsche Bedeutung → Einträge (für die Spracherkennung).
  final VocabLookup lookupGerman;

  /// Eigene Karten der Zielsprache: Vergleichsschlüssel der Vorderseite →
  /// Rückseite. So werden früher aufgenommene neue Wörter wiedererkannt.
  final Map<String, String> myCards;

  /// Sprache je Abschnitt, optional mit ML-Kit-Hinweisen pro Zeile.
  List<List<TextSegment>> segment(
    List<String> lines, {
    Map<int, Map<String, double>> hints = const {},
  }) {
    final out = <List<TextSegment>>[];
    for (var i = 0; i < lines.length; i++) {
      final parts = lines[i]
          .split(_segmentSplit)
          .map((p) => p.trim())
          .where((p) => wordsOf(p).isNotEmpty)
          .toList();
      out.add([
        for (final p in parts)
          TextSegment(p, _guess(p, parts.length == 1 ? hints[i] : null)),
      ]);
    }
    return out;
  }

  String? _guess(String text, Map<String, double>? hint) {
    final words = wordsOf(text);
    final hits = <String, int>{'es': 0, 'tr': 0, 'de': 0};
    for (final w in words) {
      if (w.length < 2) continue;
      if (lookupForeign('es', w).isNotEmpty) hits['es'] = hits['es']! + 1;
      if (lookupForeign('tr', w).isNotEmpty) hits['tr'] = hits['tr']! + 1;
      if (lookupGerman('es', w).isNotEmpty ||
          lookupGerman('tr', w).isNotEmpty) {
        hits['de'] = hits['de']! + 1;
      }
    }
    return guessLanguage(text, dbHits: hits, hint: hint ?? const {}).best;
  }

  /// Häufigste Fremdsprache im Text (für die Vorauswahl).
  String? dominantForeignLanguage(List<List<TextSegment>> segments) {
    final counts = <String, int>{};
    for (final line in segments) {
      for (final s in line) {
        if (s.language == 'es' || s.language == 'tr') {
          counts[s.language!] =
              (counts[s.language!] ?? 0) + wordsOf(s.text).length;
        }
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Extrahiert Wörter der Zielsprache [language].
  List<ExtractedWord> extract(
    List<List<TextSegment>> segments,
    String language,
  ) {
    final byKey = <String, ExtractedWord>{};

    void add(ExtractedWord w) {
      final key = _key(w.front);
      if (key.isEmpty) return;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = w;
      } else {
        existing.count++;
        if (existing.back.isEmpty && w.back.isNotEmpty) {
          existing
            ..back = w.back
            ..source = w.source;
        }
      }
    }

    for (final line in segments) {
      final foreign = line.where((s) => s.language == language).toList();
      final german = line.where((s) => s.language == 'de').toList();
      for (final seg in foreign) {
        final words = wordsOf(seg.text);
        // Paar oder kurzer Eintrag („la casa – das Haus“, „buenos días“)
        if (german.isNotEmpty ||
            (words.length <= 3 &&
                line.length == 1 &&
                _isShortEntry(seg.text))) {
          final w = _fromPhrase(
            seg.text,
            language,
            sheetTranslation: german.isEmpty ? null : german.first.text,
          );
          if (w != null) add(w);
          continue;
        }
        // Fließtext: einzelne Wörter
        for (var i = 0; i < words.length; i++) {
          final w = _fromWord(words[i], language, sentenceStart: i == 0);
          if (w != null) add(w);
        }
      }
    }
    return byKey.values.toList();
  }

  bool _isShortEntry(String text) => !RegExp(r'[.!?]$').hasMatch(text.trim());

  ExtractedWord? _fromPhrase(
    String text,
    String language, {
    String? sheetTranslation,
  }) {
    final normalized = normalizeKey(text);
    if (normalized.isEmpty) return null;
    final words = wordsOf(text);
    // Ein Wort (ggf. mit Artikel) → lemmatisieren; sonst als Wendung lassen.
    final content = words
        .where((w) => !_articlesOnly.contains(w.toLowerCase()))
        .toList();
    LemmaResult? lemma;
    final direct = lookupForeign(language, normalized);
    if (direct.isNotEmpty) {
      lemma = LemmaResult(
        direct.first.lemma,
        LemmaMethod.database,
        entry: direct.first,
        surface: normalized,
      );
    } else if (content.length == 1) {
      lemma = lemmatizer.lemmatize(language, content.first);
    }
    final entry = lemma?.entry;
    final front =
        entry?.cardFront ??
        (lemma?.found == true ? lemma!.lemma : _clean(text));
    return _build(
      surface: text.trim(),
      front: front,
      entry: entry,
      sheetTranslation: sheetTranslation,
      isNoise: false,
    );
  }

  ExtractedWord? _fromWord(
    String raw,
    String language, {
    required bool sentenceStart,
  }) {
    if (raw.length < 2) return null;
    final lower = raw.replaceAll('İ', 'i').toLowerCase();
    if (_articlesOnly.contains(lower) && language == 'es') return null;
    final lemma = lemmatizer.lemmatize(language, raw);
    final capitalized = raw[0] != raw[0].toLowerCase();
    // Großgeschrieben mitten im Satz und unbekannt → vermutlich ein Name.
    final isName = capitalized && !sentenceStart && !lemma.found;
    final isFunction = _functionWords[language]?.contains(lower) ?? false;
    final entry = lemma.entry;
    return _build(
      surface: raw,
      front: entry?.cardFront ?? lemma.lemma,
      entry: entry,
      isNoise: isName || isFunction,
      example: lemma.lemma != lower ? raw : null,
    );
  }

  ExtractedWord _build({
    required String surface,
    required String front,
    required VocabEntry? entry,
    String? sheetTranslation,
    required bool isNoise,
    String? example,
  }) {
    final mine = myCards[_key(front)] ?? myCards[_key(surface)];
    final String back;
    final TranslationSource source;
    if (sheetTranslation != null && sheetTranslation.trim().isNotEmpty) {
      back = sheetTranslation.trim();
      source = TranslationSource.sheet;
    } else if (mine != null) {
      back = mine;
      source = TranslationSource.myCards;
    } else if (entry != null) {
      back = entry.cardBack;
      source = TranslationSource.vocabDb;
    } else {
      back = '';
      source = TranslationSource.none;
    }
    final already = mine != null;
    return ExtractedWord(
      surface: surface,
      front: front,
      back: back,
      source: source,
      entry: entry,
      alreadyInCards: already,
      isNoise: isNoise,
      selected: !isNoise && !already,
      example: example,
    );
  }

  static String _clean(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _key(String front) {
    var k = normalizeKey(front);
    for (final a in const ['el ', 'la ', 'los ', 'las ', 'un ', 'una ']) {
      if (k.startsWith(a)) return k.substring(a.length);
    }
    return k;
  }
}
