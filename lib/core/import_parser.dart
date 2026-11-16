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

/// Eine Zeile einer Vokabeldatei (CSV/TSV): Vorderseite, Rückseite und
/// optional eine Gruppe (z. B. Lektion), aus der je ein Set entsteht.
class VocabFileRow {
  const VocabFileRow(this.front, this.back, [this.group]);

  final String front;
  final String back;
  final String? group;

  @override
  String toString() => 'VocabFileRow($front | $back | $group)';
}

class VocabFile {
  const VocabFile(this.rows, this.invalidLines, {this.languageHint});

  final List<VocabFileRow> rows;
  final List<int> invalidLines;

  /// Sprache laut Kopfzeile (`es`/`tr`), z. B. „türkisch;deutsch;lektion“.
  final String? languageHint;

  /// Gruppen in natürlicher Reihenfolge („Unidad 2“ vor „Unidad 10“).
  List<String> get groups {
    final set = <String>{for (final r in rows) r.group ?? ''};
    final list = set.toList()..sort(naturalCompare);
    return list;
  }
}

/// Liest eine Vokabeldatei: Trennzeichen „;“, „,“ oder Tab (automatisch),
/// Felder in Anführungszeichen erlaubt, optionale Kopfzeile
/// (z. B. `spanisch;deutsch;lektion`).
VocabFile parseVocabFile(String content) {
  final text = content.startsWith('﻿') ? content.substring(1) : content;
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final firstData = lines.firstWhere(
    (l) => l.trim().isNotEmpty,
    orElse: () => '',
  );
  final sep = _detectFileSeparator(firstData);

  final rows = <VocabFileRow>[];
  final invalid = <int>[];
  var headerChecked = false;
  String? languageHint;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final fields = _splitCsvLine(lines[i], sep);
    if (!headerChecked) {
      headerChecked = true;
      final joined = fields.join(' ').toLowerCase();
      if (RegExp(r'deutsch|german|übersetzung|lektion|unit|vorderseite')
          .hasMatch(joined)) {
        if (RegExp(r't[üu]rk').hasMatch(joined)) languageHint = 'tr';
        if (RegExp(r'spani|españ|espan').hasMatch(joined)) languageHint = 'es';
        continue;
      }
    }
    if (fields.length < 2 ||
        fields[0].trim().isEmpty ||
        fields[1].trim().isEmpty) {
      invalid.add(i + 1);
      continue;
    }
    final group = fields.length > 2 && fields[2].trim().isNotEmpty
        ? fields[2].trim()
        : null;
    rows.add(VocabFileRow(fields[0].trim(), fields[1].trim(), group));
  }
  return VocabFile(rows, invalid, languageHint: languageHint);
}

String _detectFileSeparator(String line) {
  int count(String s) => _splitCsvLine(line, s).length;
  final candidates = ['\t', ';', ','];
  var best = ';';
  var bestCount = 1;
  for (final c in candidates) {
    final n = count(c);
    if (n > bestCount) {
      best = c;
      bestCount = n;
    }
  }
  return best;
}

/// Teilt eine CSV-Zeile; Anführungszeichen schützen Trennzeichen,
/// doppelte Anführungszeichen ("") stehen für eines.
List<String> _splitCsvLine(String line, String sep) {
  final out = <String>[];
  final buf = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        buf.write(ch);
      }
    } else if (ch == '"' && buf.toString().trim().isEmpty) {
      quoted = true;
      buf.clear();
    } else if (ch == sep) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}

/// Vergleich mit Zahlen als Zahlen: „Unidad 2“ < „Unidad 10“.
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = (na != null && nb != null)
        ? na.compareTo(nb)
        : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
