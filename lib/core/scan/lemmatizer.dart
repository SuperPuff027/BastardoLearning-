import '../../data/vocab/vocab_entry.dart';
import '../../data/vocab/vocab_repository.dart' show normalizeKey;

/// Sucht eine Wortform in der Vokabeldatenbank (Grundform oder gebeugt).
typedef VocabLookup = List<VocabEntry> Function(String language, String form);

enum LemmaMethod {
  /// Form steht direkt in der Datenbank (Grundform oder gespeicherte Form).
  database,

  /// Über Endungs- bzw. Suffixregeln auf einen Datenbank-Eintrag zurückgeführt.
  rules,

  /// Nicht gefunden – Originalform (klein geschrieben) bleibt.
  unchanged,
}

class LemmaResult {
  const LemmaResult(this.lemma, this.method, {this.entry, this.surface = ''});

  final String lemma;
  final LemmaMethod method;
  final VocabEntry? entry;
  final String surface;

  bool get found => entry != null;

  @override
  String toString() => 'LemmaResult($surface → $lemma, $method)';
}

/// Rückführung auf die Grundform (Brief Abschnitt 3: „Lemmatisierung ist
/// Pflicht“). Grundlage sind die Formen der Vokabeldatenbank; Regeln
/// erzeugen Kandidaten, die nur gelten, wenn die Datenbank sie kennt.
class Lemmatizer {
  Lemmatizer(this.lookup);

  final VocabLookup lookup;

  LemmaResult lemmatize(String language, String word) {
    final surface = normalizeKey(word);
    if (surface.isEmpty) {
      return const LemmaResult('', LemmaMethod.unchanged);
    }
    final direct = lookup(language, surface);
    if (direct.isNotEmpty) {
      return LemmaResult(
        direct.first.lemma,
        LemmaMethod.database,
        entry: direct.first,
        surface: surface,
      );
    }
    final viaRules = switch (language) {
      'es' => _spanish(surface),
      'tr' => _turkish(surface),
      _ => null,
    };
    if (viaRules != null) {
      return LemmaResult(
        viaRules.lemma,
        LemmaMethod.rules,
        entry: viaRules,
        surface: surface,
      );
    }
    return LemmaResult(surface, LemmaMethod.unchanged, surface: surface);
  }

  VocabEntry? _first(String language, String candidate) {
    final r = lookup(language, candidate);
    return r.isEmpty ? null : r.first;
  }

  // ------------------------------------------------------------ Spanisch

  /// Endung → mögliche Infinitiv-Endungen (längste Endungen zuerst prüfen).
  static const _esVerbEndings = <String, List<String>>{
    // -ar
    'ábamos': ['ar'], 'aríamos': ['ar'], 'asteis': ['ar'], 'aremos': ['ar'],
    'aron': ['ar'], 'aban': ['ar'], 'abas': ['ar'], 'aste': ['ar'],
    'ando': ['ar'], 'aría': ['ar'], 'arán': ['ar'], 'aré': ['ar'],
    'ará': ['ar'], 'aba': ['ar'], 'ado': ['ar'], 'ada': ['ar'],
    'ados': ['ar'], 'adas': ['ar'], 'amos': ['ar'], 'áis': ['ar'],
    'an': ['ar', 'er', 'ir'], 'as': ['ar'], 'ó': ['ar'], 'é': ['ar'],
    // -er / -ir
    'iéramos': ['er', 'ir'], 'eríamos': ['er'], 'iríamos': ['ir'],
    'ieron': ['er', 'ir'], 'isteis': ['er', 'ir'], 'íamos': ['er', 'ir'],
    'iendo': ['er', 'ir'], 'yendo': ['er', 'ir'], 'ieron ': ['er', 'ir'],
    'emos': ['er'], 'imos': ['ir', 'er'], 'éis': ['er'], 'ís': ['ir'],
    'iste': ['er', 'ir'], 'ían': ['er', 'ir'], 'ías': ['er', 'ir'],
    'ido': ['er', 'ir'], 'ida': ['er', 'ir'], 'idos': ['er', 'ir'],
    'idas': ['er', 'ir'], 'ería': ['er'], 'iría': ['ir'], 'erá': ['er'],
    'irá': ['ir'], 'eré': ['er'], 'iré': ['ir'], 'ió': ['er', 'ir'],
    'ía': ['er', 'ir'], 'en': ['er', 'ir', 'ar'], 'es': ['er', 'ir', 'ar'],
    'í': ['er', 'ir'], 'o': ['ar', 'er', 'ir'], 'a': ['ar', 'er', 'ir'],
    'e': ['er', 'ir', 'ar'],
  };

  /// Stammänderungen im Präsens (vuelvo → volver, quiero → querer, pido → pedir).
  static const _stemChanges = [
    ('ue', 'o'),
    ('ie', 'e'),
    ('i', 'e'),
    ('u', 'o'),
  ];

  VocabEntry? _spanish(String w) {
    // Plural und Femininum/Plural von Adjektiven
    final nominal = <String>[
      if (w.endsWith('ces')) '${w.substring(0, w.length - 3)}z',
      if (w.endsWith('es')) w.substring(0, w.length - 2),
      if (w.endsWith('s')) w.substring(0, w.length - 1),
      if (w.endsWith('as')) '${w.substring(0, w.length - 2)}o',
      if (w.endsWith('os')) '${w.substring(0, w.length - 2)}o',
      if (w.endsWith('a')) '${w.substring(0, w.length - 1)}o',
    ];
    for (final c in nominal) {
      if (c.length >= 2) {
        final e = _first('es', c);
        if (e != null) return e;
      }
    }
    // Verben (inkl. Akzentvarianten des Stamms wie „pidió“ → pedir)
    final endings = _esVerbEndings.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final end in endings) {
      if (!w.endsWith(end)) continue;
      final stem = w.substring(0, w.length - end.length);
      if (stem.length < 2) continue;
      for (final inf in _esVerbEndings[end]!) {
        for (final s in [stem, ..._stemVariants(stem)]) {
          for (final candidate in ['$s$inf', '$s${inf}se']) {
            final e = _first('es', candidate);
            if (e != null && e.pos == 'verb') return e;
          }
        }
      }
    }
    return null;
  }

  static Iterable<String> _stemVariants(String stem) sync* {
    for (final (from, to) in _stemChanges) {
      final i = stem.lastIndexOf(from);
      if (i >= 0) {
        yield stem.replaceRange(i, i + from.length, to);
      }
    }
    // g/c-Wechsel (hago → hacer, pongo → poner, conozco → conocer)
    if (stem.endsWith('zc')) yield '${stem.substring(0, stem.length - 2)}c';
    if (stem.endsWith('g')) {
      yield stem.substring(0, stem.length - 1);
      yield '${stem.substring(0, stem.length - 1)}c';
    }
    if (stem.endsWith('qu')) yield '${stem.substring(0, stem.length - 2)}c';
    if (stem.endsWith('gu')) yield '${stem.substring(0, stem.length - 2)}g';
  }

  // ------------------------------------------------------------- Türkisch

  /// Suffixe in allen Varianten der Vokalharmonie und Konsonantenangleichung.
  static final List<String> _trSuffixes = () {
    const groups = [
      // Plural
      'lar ler',
      // Possessiv
      'ımız imiz umuz ümüz mız miz muz müz ınız iniz unuz ünüz nız niz nuz nüz '
          'ları leri ım im um üm ın in un ün sı si su sü m n',
      // Kasus
      'ndan nden dan den tan ten nda nde da de ta te '
          'nın nin nun nün ın in un ün yla yle la le '
          'yı yi yu yü nı ni nu nü ı i u ü ya ye na ne a e',
      // Kopula / Person
      'sınız siniz sunuz sünüz yız yiz yuz yüz ız iz uz üz yım yim yum yüm '
          'sın sin sun sün dır dir dur dür tır tir tur tür',
      // Verb: Zeit, Modus, Verneinung, Infinitiv
      'ıyor iyor uyor üyor yor acak ecek yacak yecek mış miş muş müş '
          'dı di du dü tı ti tu tü malı meli ma me mak mek '
          'abil ebil yabil yebil ar er ır ir ur ür ken sa se ki k',
    ];
    final all = groups.expand((g) => g.split(' ')).where((s) => s.isNotEmpty);
    final list = all.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return list;
  }();

  /// Konsonantenerweichung rückgängig: kitab(ı) → kitap, ağac(ı) → ağaç.
  static Iterable<String> _unsoften(String stem) sync* {
    yield stem;
    if (stem.isEmpty) return;
    final last = stem[stem.length - 1];
    final base = stem.substring(0, stem.length - 1);
    switch (last) {
      case 'b':
        yield '${base}p';
      case 'c':
        yield '$baseç';
      case 'd':
        yield '${base}t';
      case 'ğ':
        yield '${base}k';
        yield '${base}g';
    }
  }

  VocabEntry? _turkish(String w) {
    // Breitensuche: wenige abgetrennte Suffixe bevorzugen.
    var frontier = <String>{w};
    final seen = <String>{w};
    for (var depth = 0; depth < 6 && frontier.isNotEmpty; depth++) {
      final next = <String>{};
      for (final current in frontier) {
        for (final suffix in _trSuffixes) {
          if (!current.endsWith(suffix)) continue;
          final stem = current.substring(0, current.length - suffix.length);
          if (stem.length < 2) continue;
          for (final s in _unsoften(stem)) {
            final noun = _first('tr', s);
            if (noun != null) return noun;
            for (final inf in ['mak', 'mek']) {
              final verb = _first('tr', '$s$inf');
              if (verb != null && verb.pos == 'verb') return verb;
            }
          }
          if (seen.add(stem)) next.add(stem);
        }
      }
      frontier = next;
    }
    return null;
  }
}
