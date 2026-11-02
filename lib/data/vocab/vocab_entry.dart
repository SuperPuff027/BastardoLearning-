import 'dart:convert';

/// Eintrag der mitgelieferten Vokabeldatenbank (Brief Abschnitt 5).
class VocabEntry {
  const VocabEntry({
    required this.id,
    required this.language,
    required this.lemma,
    required this.pos,
    required this.cefrLevel,
    required this.translations,
    this.gender,
    this.article,
    this.frequencyRank,
    this.example = '',
    this.exampleTranslation = '',
    this.forms = const [],
    this.tags = const [],
    this.verified = false,
  });

  factory VocabEntry.fromRow(Map<String, Object?> r) => VocabEntry(
    id: r['id']! as int,
    language: r['language']! as String,
    lemma: r['lemma']! as String,
    pos: r['pos']! as String,
    gender: r['gender'] as String?,
    article: r['article'] as String?,
    cefrLevel: r['cefr_level']! as String,
    frequencyRank: r['frequency_rank'] as int?,
    translations: _list(r['translations_de']),
    example: (r['example_sentence'] as String?) ?? '',
    exampleTranslation: (r['example_translation'] as String?) ?? '',
    forms: _list(r['forms']),
    tags: _list(r['tags']),
    verified: r['verified'] == 1,
  );

  static List<String> _list(Object? json) => json == null
      ? const []
      : (jsonDecode(json as String) as List).cast<String>();

  final int id;
  final String language;
  final String lemma;
  final String pos;
  final String? gender;
  final String? article;
  final String cefrLevel;
  final int? frequencyRank;
  final List<String> translations;
  final String example;
  final String exampleTranslation;
  final List<String> forms;
  final List<String> tags;
  final bool verified;

  /// Vorderseite einer Karte: spanische Nomen mit Artikel („la casa“);
  /// Nomen mit beiden Genera als „estudiante (m./f.)“.
  String get cardFront {
    if (gender == 'mf') return '$lemma (m./f.)';
    if (article != null) return '$article $lemma';
    return lemma;
  }

  /// Rückseite: bis zu drei Bedeutungen, Hauptbedeutung zuerst.
  String get cardBack => translations.take(3).join(', ');

  String get posLabel => switch (pos) {
    'noun' => 'Nomen',
    'verb' => 'Verb',
    'adj' => 'Adjektiv',
    'adv' => 'Adverb',
    'pron' => 'Pronomen',
    'prep' => 'Präposition',
    'conj' => 'Konjunktion',
    'det' => 'Begleiter',
    'num' => 'Zahlwort',
    'interj' => 'Ausruf',
    'phrase' => 'Wendung',
    _ => pos,
  };

  @override
  bool operator ==(Object other) => other is VocabEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VocabEntry($id $language:$lemma)';
}

/// Themen der vorgefertigten Sets (Schlüssel wie in tools/vocab/vocab_schema.py).
const vocabTags = {
  'alltag': 'Alltag',
  'arbeit': 'Arbeit & Beruf',
  'einkaufen': 'Einkaufen & Geld',
  'essen': 'Essen & Trinken',
  'familie': 'Familie & Menschen',
  'farben': 'Farben & Formen',
  'freizeit': 'Freizeit & Hobbys',
  'gefuehle': 'Gefühle & Eigenschaften',
  'gesundheit': 'Körper & Gesundheit',
  'grammatik': 'Grundwörter & Grammatik',
  'kleidung': 'Kleidung',
  'kommunikation': 'Kommunikation',
  'natur': 'Natur & Wetter',
  'reisen': 'Reisen & Verkehr',
  'schule': 'Schule & Lernen',
  'stadt': 'Stadt & Orte',
  'tiere': 'Tiere',
  'wohnen': 'Wohnen & Haushalt',
  'zahlen': 'Zahlen & Mengen',
  'zeit': 'Zeit & Kalender',
};

/// Gruppe für vorgefertigte Sets: Niveau + optional Thema.
class PresetGroup {
  const PresetGroup(this.language, this.cefrLevel, this.tag, this.count);

  final String language;
  final String cefrLevel;

  /// `null` = alle Wörter des Niveaus („Grundwortschatz“).
  final String? tag;
  final int count;

  String get label => tag == null
      ? 'Grundwortschatz $cefrLevel'
      : '$cefrLevel – ${vocabTags[tag] ?? tag}';
}
