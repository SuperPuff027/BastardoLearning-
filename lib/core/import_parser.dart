/// Trennzeichen für den Text-Import (Excel, Word, Textdateien).
enum ImportSeparator {
  tab('\t', 'Tab'),
  comma(',', 'Komma'),
  semicolon(';', 'Semikolon'),
  dash('-', 'Bindestrich „-“');

  const ImportSeparator(this.char, this.label);

  final String char;
  final String label;
}

class ImportedPair {
  const ImportedPair(this.front, this.back);

  final String front;
  final String back;

  @override
  bool operator ==(Object other) =>
      other is ImportedPair && other.front == front && other.back == back;

  @override
  int get hashCode => Object.hash(front, back);

  @override
  String toString() => 'ImportedPair($front | $back)';
}

class ImportResult {
  const ImportResult(this.pairs, this.invalidLines);

  final List<ImportedPair> pairs;

  /// 1-basierte Zeilennummern, die nicht gelesen werden konnten.
  final List<int> invalidLines;
}

/// Zerlegt eingefügten Text in Kartenpaare: eine Karte pro Zeile,
/// Vorderseite und Rückseite durch [separator] getrennt.
///
/// Getrennt wird beim ersten Vorkommen; der Rest gehört zur Rückseite
/// („casa, Haus, Heim“ → „casa“ | „Haus, Heim“). Beim Bindestrich wird
/// „ - “ (mit Leerzeichen) bevorzugt, damit Wörter wie „bien-estar“ heil
/// bleiben. Leere Zeilen werden übersprungen.
ImportResult parseImport(String input, ImportSeparator separator) {
  final pairs = <ImportedPair>[];
  final invalid = <int>[];
  final lines = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;

    var index = -1;
    var sepLength = separator.char.length;
    if (separator == ImportSeparator.dash) {
      final spaced = RegExp(r'\s[-–—]\s').firstMatch(line);
      if (spaced != null) {
        index = spaced.start;
        sepLength = spaced.end - spaced.start;
      } else {
        index = line.indexOf('-');
      }
    } else {
      index = line.indexOf(separator.char);
    }

    if (index < 0) {
      invalid.add(i + 1);
      continue;
    }
    final front = _clean(line.substring(0, index));
    final back = _clean(line.substring(index + sepLength));
    if (front.isEmpty || back.isEmpty) {
      invalid.add(i + 1);
      continue;
    }
    pairs.add(ImportedPair(front, back));
  }
  return ImportResult(pairs, invalid);
}

/// Wählt das Trennzeichen, mit dem sich die meisten Zeilen lesen lassen.
/// Bei Gleichstand gewinnt die Reihenfolge Tab, Semikolon, Komma, Bindestrich.
ImportSeparator detectSeparator(String input) {
  const order = [
    ImportSeparator.tab,
    ImportSeparator.semicolon,
    ImportSeparator.comma,
    ImportSeparator.dash,
  ];
  var best = ImportSeparator.tab;
  var bestCount = -1;
  for (final sep in order) {
    final count = parseImport(input, sep).pairs.length;
    if (count > bestCount) {
      best = sep;
      bestCount = count;
    }
  }
  return best;
}

/// Entfernt Leerzeichen und Anführungszeichen, wie Excel sie bei CSV setzt.
String _clean(String s) {
  var t = s.trim();
  if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
    t = t.substring(1, t.length - 1).replaceAll('""', '"').trim();
  }
  return t;
}
