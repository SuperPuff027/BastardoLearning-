/// Smarte Bewertung getippter Antworten (Brief Nr. 18).
///
/// Regeln:
/// - Groß-/Kleinschreibung, Satzzeichen am Rand und doppelte Leerzeichen
///   sind egal.
/// - Artikel sind optional („casa“ für „la casa“ ist richtig). Ein falscher
///   Artikel („el casa“) gilt als fast richtig.
/// - Mehrere Bedeutungen („Haus, Heim“ oder „Haus / Heim“): jede zählt.
/// - Klammerinhalte sind optional („(sich) freuen“).
/// - Fehlende Akzente (á/a, ñ/n, ş/s, ğ/g, ı/i, ç/c, ä/a, ß/ss …) → fast richtig.
/// - Ein Tippfehler (Levenshtein ≤ 1) bei Wörtern ab 5 Zeichen → fast richtig.
library;

enum Verdict { correct, almostCorrect, wrong }

enum AlmostReason { accents, typo, article }

class GradeResult {
  const GradeResult(this.verdict, {this.reason, this.matched});

  final Verdict verdict;

  /// Warum die Antwort nur fast richtig ist.
  final AlmostReason? reason;

  /// Die Variante der erwarteten Antwort, die gepasst hat.
  final String? matched;

  /// Fast richtig zählt als gewusst.
  bool get isAccepted => verdict != Verdict.wrong;

  String? get hint => switch (reason) {
    AlmostReason.accents => 'Achte auf die Akzente bzw. Sonderzeichen.',
    AlmostReason.typo => 'Fast – da ist ein Tippfehler drin.',
    AlmostReason.article => 'Der Artikel stimmt nicht.',
    null => null,
  };
}

const _articles = {
  // Spanisch
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'lo',
  // Deutsch
  'der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen',
  'einem', 'einer', 'eines',
};

const _fold = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ı': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ş': 's',
  'ğ': 'g',
  'ß': 'ss',
};

GradeResult gradeAnswer(String given, String expected) {
  final answer = _Parsed(_normalize(given));
  if (answer.word.isEmpty) return const GradeResult(Verdict.wrong);

  GradeResult? best;
  for (final variant in expectedVariants(expected)) {
    final target = _Parsed(_normalize(variant));
    if (target.word.isEmpty) continue;
    final result = _compare(answer, target, variant);
    if (result.verdict == Verdict.correct) return result;
    if (result.verdict == Verdict.almostCorrect) best ??= result;
  }
  return best ?? const GradeResult(Verdict.wrong);
}

GradeResult _compare(_Parsed a, _Parsed t, String variant) {
  final articleMismatch =
      a.article != null && t.article != null && a.article != t.article;
  // Ein Artikel bei der Antwort, den es im Ziel nicht gibt, zählt als Teil
  // des Wortes, falls es sonst nicht passt („das“ als Antwort auf „das“).
  if (a.word == t.word) {
    return articleMismatch
        ? GradeResult(
            Verdict.almostCorrect,
            reason: AlmostReason.article,
            matched: variant,
          )
        : GradeResult(Verdict.correct, matched: variant);
  }
  if (a.full == t.full) return GradeResult(Verdict.correct, matched: variant);

  final fa = foldAccents(a.word);
  final ft = foldAccents(t.word);
  if (fa == ft) {
    return GradeResult(
      Verdict.almostCorrect,
      reason: AlmostReason.accents,
      matched: variant,
    );
  }
  if (ft.length >= 5 && levenshtein(fa, ft, max: 1) <= 1) {
    return GradeResult(
      Verdict.almostCorrect,
      reason: AlmostReason.typo,
      matched: variant,
    );
  }
  return const GradeResult(Verdict.wrong);
}

/// Alle akzeptierten Schreibweisen einer erwarteten Antwort.
List<String> expectedVariants(String expected) {
  final out = <String>{};
  for (final part in expected.split(RegExp(r'[,;/]|\s\|\s'))) {
    final p = part.trim();
    if (p.isEmpty) continue;
    out.add(p);
    if (p.contains('(')) {
      out.add(p.replaceAll(RegExp(r'\([^)]*\)'), ' ').trim());
      out.add(p.replaceAll(RegExp(r'[()]'), '').trim());
    }
  }
  out.removeWhere((v) => v.isEmpty);
  if (out.isEmpty) out.add(expected.trim());
  return out.toList();
}

String foldAccents(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    b.write(_fold[ch] ?? ch);
  }
  return b.toString();
}

/// Kleinbuchstaben (inkl. türkischem İ), ohne Satzzeichen am Rand,
/// einfache Leerzeichen.
String _normalize(String s) {
  var t = s.replaceAll('İ', 'i').toLowerCase();
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(
    RegExp(r'''^[\s.,!?¡¿;:"'«»„“”‚‘’…-]+|[\s.,!?¡¿;:"'«»„“”‚‘’…-]+$'''),
    '',
  );
  return t;
}

class _Parsed {
  factory _Parsed(String normalized) {
    final space = normalized.indexOf(' ');
    if (space > 0) {
      final first = normalized.substring(0, space);
      if (_articles.contains(first)) {
        return _Parsed._(
          normalized,
          first,
          normalized.substring(space + 1).trim(),
        );
      }
    }
    return _Parsed._(normalized, null, normalized);
  }

  _Parsed._(this.full, this.article, this.word);

  final String full;
  final String? article;
  final String word;
}

/// Levenshtein-Distanz; bricht ab, sobald [max] sicher überschritten ist.
int levenshtein(String a, String b, {int? max}) {
  if (a == b) return 0;
  if (max != null && (a.length - b.length).abs() > max) return max + 1;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    var rowMin = curr[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final v = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      curr[j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (max != null && rowMin > max) return max + 1;
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}
