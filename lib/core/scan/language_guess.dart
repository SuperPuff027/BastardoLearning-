/// Spracherkennung pro Textabschnitt (es / tr / de).
///
/// Kombiniert typische Zeichen, häufige Funktionswörter, Treffer in der
/// Vokabeldatenbank und – falls vorhanden – das Ergebnis von ML Kit.
library;

const guessLanguages = ['es', 'tr', 'de'];

const _stopwords = {
  'es': {
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'y',
    'que',
    'en',
    'es',
    'por',
    'con',
    'para',
    'del',
    'al',
    'mi',
    'su',
    'no',
    'se',
    'lo',
    'muy',
    'pero',
    'como',
    'más',
    'este',
    'esta',
    'yo',
    'tú',
    'hay',
    'son',
    'está',
  },
  'tr': {
    'bir',
    've',
    'bu',
    'şu',
    'çok',
    'için',
    'ile',
    'var',
    'yok',
    'mi',
    'mı',
    'mu',
    'mü',
    'ne',
    'ben',
    'sen',
    'biz',
    'siz',
    'onlar',
    'gibi',
    'ama',
    'daha',
    'değil',
    'her',
    'olarak',
    'kadar',
  },
  'de': {
    'der',
    'die',
    'das',
    'und',
    'ist',
    'ein',
    'eine',
    'nicht',
    'ich',
    'du',
    'er',
    'sie',
    'es',
    'wir',
    'ihr',
    'mit',
    'zu',
    'den',
    'dem',
    'im',
    'auf',
    'für',
    'von',
    'sich',
    'auch',
    'aber',
    'wie',
    'was',
    'sein',
    'haben',
  },
};

/// Wortzeichen inkl. Akzente und türkischer Buchstaben.
final wordPattern = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿĞğİıŞşÇçÑñÜüÖöÄäß]+");

List<String> wordsOf(String text) =>
    wordPattern.allMatches(text).map((m) => m.group(0)!).toList();

class LanguageScores {
  LanguageScores(this.scores);

  final Map<String, double> scores;

  /// Beste Sprache oder `null`, wenn nichts darauf hindeutet.
  String? get best {
    String? bestLang;
    var bestScore = 0.0;
    for (final e in scores.entries) {
      if (e.value > bestScore) {
        bestScore = e.value;
        bestLang = e.key;
      }
    }
    return bestLang;
  }

  @override
  String toString() => 'LanguageScores($scores)';
}

/// [dbHits]: Anzahl der Wörter, die in der Datenbank als es-/tr-Wort bzw.
/// als deutsche Bedeutung gefunden wurden. [hint]: Sprache → Konfidenz von
/// ML Kit (optional).
LanguageScores guessLanguage(
  String text, {
  Map<String, int> dbHits = const {},
  Map<String, double> hint = const {},
}) {
  final scores = {for (final l in guessLanguages) l: 0.0};
  final lower = text.toLowerCase();

  for (final r in lower.runes) {
    switch (String.fromCharCode(r)) {
      case 'ñ' || '¿' || '¡' || 'á' || 'é' || 'í' || 'ó' || 'ú':
        scores['es'] = scores['es']! + 3;
      case 'ş' || 'ğ' || 'ı':
        scores['tr'] = scores['tr']! + 3;
      case 'ç':
        scores['tr'] = scores['tr']! + 2;
      case 'ä' || 'ß':
        scores['de'] = scores['de']! + 3;
      case 'ö' || 'ü':
        scores['tr'] = scores['tr']! + 1;
        scores['de'] = scores['de']! + 1;
    }
  }
  if (text.contains('İ')) scores['tr'] = scores['tr']! + 3;

  final words = wordsOf(lower);
  for (final w in words) {
    for (final l in guessLanguages) {
      if (_stopwords[l]!.contains(w)) scores[l] = scores[l]! + 1.5;
    }
  }
  // Deutsche Nomen werden großgeschrieben (schwacher Hinweis bei Paaren).
  final capitalizedNouns = wordsOf(text)
      .skip(1)
      .where((w) => w[0] == w[0].toUpperCase())
      .length;
  scores['de'] = scores['de']! + capitalizedNouns * 0.5;

  for (final e in dbHits.entries) {
    scores[e.key] = (scores[e.key] ?? 0) + e.value * 1.0;
  }
  for (final e in hint.entries) {
    if (scores.containsKey(e.key)) {
      scores[e.key] = scores[e.key]! + e.value * 3;
    }
  }
  return LanguageScores(scores);
}
