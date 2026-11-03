import 'package:flutter/foundation.dart' show kIsWeb;

/// Lernsprachen. Die Architektur ist sprachneutral: Für eine neue Sprache
/// genügt ein weiterer Eintrag hier (plus Vokabeldaten ab Meilenstein 4).
enum StudyLanguage {
  es('Spanisch', '🇪🇸'),
  tr('Türkisch', '🇹🇷');

  const StudyLanguage(this.label, this.emoji);

  final String label;
  final String emoji;

  /// Flagge als Emoji; im Browser als Kürzel („ES“), weil Flaggen-Emojis
  /// dort eine Online-Schrift bräuchten (offline sonst leer).
  String get flag => kIsWeb ? code.toUpperCase() : emoji;

  /// ISO-639-1-Code, so wie er in der Datenbank steht.
  String get code => name;

  static StudyLanguage? fromCode(String code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }

  static String labelFor(String code) => fromCode(code)?.label ?? code;
}
