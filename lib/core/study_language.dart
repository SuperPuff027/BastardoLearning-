/// Lernsprachen. Die Architektur ist sprachneutral: Für eine neue Sprache
/// genügt ein weiterer Eintrag hier (plus Vokabeldaten ab Meilenstein 4).
enum StudyLanguage {
  es('Spanisch', '🇪🇸'),
  tr('Türkisch', '🇹🇷');

  const StudyLanguage(this.label, this.flag);

  final String label;
  final String flag;

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
