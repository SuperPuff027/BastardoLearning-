import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../core/learning/grading.dart' show foldAccents;
import 'vocab_entry.dart';

/// Lesezugriff auf die mitgelieferte Vokabeldatenbank (assets/vocab/vocab.db).
///
/// Die Datei wird beim ersten Start (und nach App-Updates mit neuer Datenbank)
/// aus den Assets ins App-Verzeichnis kopiert und schreibgeschützt geöffnet.
class VocabRepository {
  VocabRepository(this._db);

  /// Öffnet eine vorhandene Datei (Tests, Werkzeuge).
  factory VocabRepository.open(String path) =>
      VocabRepository(sqlite3.open(path, mode: OpenMode.readOnly));

  static const assetPath = 'assets/vocab/vocab.db';

  /// Kopiert die Datenbank aus den Assets nach [directory], falls sie fehlt
  /// oder sich geändert hat, und öffnet sie.
  static Future<VocabRepository> install(
    Directory directory, {
    AssetBundle? bundle,
  }) async {
    final data = await (bundle ?? rootBundle).load(assetPath);
    final file = File(p.join(directory.path, 'vocab.db'));
    if (!await file.exists() || await file.length() != data.lengthInBytes) {
      await directory.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return VocabRepository.open(file.path);
  }

  final Database _db;

  void close() => _db.close();

  String meta(String key) {
    final rows = _db.select('SELECT value FROM meta WHERE key = ?', [key]);
    return rows.isEmpty ? '' : rows.first['value'] as String;
  }

  String get attribution => meta('attribution');

  int count(String language) =>
      _db.select('SELECT COUNT(*) AS n FROM vocab WHERE language = ?', [
            language,
          ]).first['n']
          as int;

  VocabEntry? byId(int id) {
    final rows = _db.select('SELECT * FROM vocab WHERE id = ?', [id]);
    return rows.isEmpty ? null : VocabEntry.fromRow(rows.first);
  }

  /// Sucht ein Fremdwort (Grundform, mit Artikel oder gebeugt).
  /// Zuerst exakt, dann ohne Akzente. Grundformen und häufige Wörter zuerst.
  List<VocabEntry> lookupForeign(String language, String text) {
    final key = normalizeKey(text);
    if (key.isEmpty) return const [];
    var rows = _formQuery(language, 'form', key);
    if (rows.isEmpty) {
      rows = _formQuery(language, 'form_folded', foldAccents(key));
    }
    return rows;
  }

  List<VocabEntry> _formQuery(String language, String column, String key) {
    final rows = _db.select(
      '''
      SELECT v.*, MAX(f.is_lemma) AS lemma_hit
      FROM vocab_form f JOIN vocab v ON v.id = f.vocab_id
      WHERE f.language = ? AND f.$column = ?
      GROUP BY v.id
      ORDER BY lemma_hit DESC, COALESCE(v.frequency_rank, 1e9)
    ''',
      [language, key],
    );
    return rows.map(VocabEntry.fromRow).toList();
  }

  /// Sucht über die deutsche Bedeutung (Artikel optional).
  List<VocabEntry> lookupGerman(String language, String text) {
    final key = stripGermanArticle(normalizeKey(text));
    if (key.isEmpty) return const [];
    var rows = _deQuery(language, 'de', key);
    if (rows.isEmpty) rows = _deQuery(language, 'de_folded', foldAccents(key));
    return rows;
  }

  List<VocabEntry> _deQuery(String language, String column, String key) {
    final rows = _db.select(
      '''
      SELECT v.*, MIN(d.position) AS pos_rank
      FROM vocab_de d JOIN vocab v ON v.id = d.vocab_id
      WHERE d.language = ? AND d.$column = ?
      GROUP BY v.id
      ORDER BY pos_rank, COALESCE(v.frequency_rank, 1e9)
    ''',
      [language, key],
    );
    return rows.map(VocabEntry.fromRow).toList();
  }

  /// Vorschläge beim Tippen: Grundformen, die mit [prefix] beginnen.
  List<VocabEntry> suggestForeign(
    String language,
    String prefix, {
    int limit = 5,
  }) {
    final key = normalizeKey(prefix);
    if (key.length < 2) return const [];
    final rows = _db.select(
      '''
      SELECT v.* FROM vocab_form f JOIN vocab v ON v.id = f.vocab_id
      WHERE f.language = ? AND f.is_lemma = 1
        AND (f.form LIKE ? ESCAPE '\\' OR f.form_folded LIKE ? ESCAPE '\\')
      GROUP BY v.id
      ORDER BY (f.form = ?) DESC, COALESCE(v.frequency_rank, 1e9)
      LIMIT ?
    ''',
      [language, '${_like(key)}%', '${_like(foldAccents(key))}%', key, limit],
    );
    return rows.map(VocabEntry.fromRow).toList();
  }

  /// Vorschläge über die deutsche Seite.
  List<VocabEntry> suggestGerman(
    String language,
    String prefix, {
    int limit = 5,
  }) {
    final key = stripGermanArticle(normalizeKey(prefix));
    if (key.length < 2) return const [];
    final rows = _db.select(
      '''
      SELECT v.* FROM vocab_de d JOIN vocab v ON v.id = d.vocab_id
      WHERE d.language = ? AND (d.de LIKE ? ESCAPE '\\' OR d.de_folded LIKE ? ESCAPE '\\')
      GROUP BY v.id
      ORDER BY MAX(d.de = ?) DESC, MIN(d.position), COALESCE(v.frequency_rank, 1e9)
      LIMIT ?
    ''',
      [language, '${_like(key)}%', '${_like(foldAccents(key))}%', key, limit],
    );
    return rows.map(VocabEntry.fromRow).toList();
  }

  /// Gruppen für vorgefertigte Sets (ab [minCount] Wörtern).
  List<PresetGroup> presetGroups(String language, {int minCount = 8}) {
    final groups = <PresetGroup>[];
    final levels = _db.select(
      '''
      SELECT cefr_level, COUNT(*) AS n FROM vocab WHERE language = ?
      GROUP BY cefr_level ORDER BY cefr_level
    ''',
      [language],
    );
    for (final l in levels) {
      final level = l['cefr_level'] as String;
      final n = l['n'] as int;
      if (n < minCount) continue;
      groups.add(PresetGroup(language, level, null, n));
      final tags = _db.select(
        '''
        SELECT j.value AS tag, COUNT(*) AS n
        FROM vocab v, json_each(v.tags) j
        WHERE v.language = ? AND v.cefr_level = ?
        GROUP BY j.value ORDER BY n DESC, j.value
      ''',
        [language, level],
      );
      for (final t in tags) {
        if ((t['n'] as int) >= minCount) {
          groups.add(
            PresetGroup(language, level, t['tag'] as String, t['n'] as int),
          );
        }
      }
    }
    return groups;
  }

  /// Einträge einer Gruppe, nach Häufigkeit sortiert.
  List<VocabEntry> entriesFor(PresetGroup group) {
    final rows = group.tag == null
        ? _db.select(
            '''
            SELECT * FROM vocab WHERE language = ? AND cefr_level = ?
            ORDER BY COALESCE(frequency_rank, 1e9), lemma
          ''',
            [group.language, group.cefrLevel],
          )
        : _db.select(
            '''
            SELECT v.* FROM vocab v, json_each(v.tags) j
            WHERE v.language = ? AND v.cefr_level = ? AND j.value = ?
            ORDER BY COALESCE(v.frequency_rank, 1e9), v.lemma
          ''',
            [group.language, group.cefrLevel, group.tag],
          );
    return rows.map(VocabEntry.fromRow).toList();
  }

  static String _like(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

const _germanArticles = [
  'der ',
  'die ',
  'das ',
  'den ',
  'dem ',
  'des ',
  'ein ',
  'eine ',
  'einen ',
];

/// Kleinbuchstaben ohne Satzzeichen am Rand und ohne Klammerzusätze
/// (gleiche Regeln wie tools/vocab/vocab_schema.py → normalize).
String normalizeKey(String text) {
  var t = text.replaceAll('İ', 'i').toLowerCase();
  t = t.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.replaceAll(
    RegExp(r'''^[\s.,;:!?¡¿"'«»„“”]+|[\s.,;:!?¡¿"'«»„“”]+$'''),
    '',
  );
}

String stripGermanArticle(String key) {
  for (final a in _germanArticles) {
    if (key.startsWith(a)) return key.substring(a.length);
  }
  return key;
}
