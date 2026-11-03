import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';
import 'media/media_store.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackupSummary {
  const BackupSummary({
    required this.sets,
    required this.cards,
    required this.media,
    required this.createdAt,
  });

  final int sets;
  final int cards;
  final int media;
  final DateTime? createdAt;
}

/// Sicherung aller Nutzerdaten als eine JSON-Datei (Brief Abschnitt 11,
/// Entscheidung 2: lokaler Export/Import, kein Cloud-Sync).
class BackupService {
  BackupService(this.db, this.media, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final MediaStore media;
  final DateTime Function() _clock;

  static const format = 'barstardo-learning-backup';
  static const formatVersion = 1;

  Future<Uint8List> export() async {
    final cards = await db.select(db.cards).get();
    final diagrams = await db.select(db.diagramPoints).get();
    final mediaKeys = <String>{
      for (final c in cards) ...[?c.imagePath, ?c.audioPath],
      for (final d in diagrams) d.imagePath,
    };
    final mediaData = <String, String>{};
    for (final key in mediaKeys) {
      final bytes = await media.read(key);
      if (bytes != null) mediaData[key] = base64Encode(bytes);
    }
    final json = {
      'format': format,
      'version': formatVersion,
      'schema': db.schemaVersion,
      'createdAt': _clock().toIso8601String(),
      'tables': {
        'folders': [
          for (final r in await db.select(db.folders).get()) r.toJson(),
        ],
        'sets': [for (final r in await db.select(db.sets).get()) r.toJson()],
        'cards': [for (final r in cards) r.toJson()],
        'diagramPoints': [for (final r in diagrams) r.toJson()],
        'reviewStates': [
          for (final r in await db.select(db.reviewStates).get()) r.toJson(),
        ],
        'reviewLogs': [
          for (final r in await db.select(db.reviewLogs).get()) r.toJson(),
        ],
        'gameScores': [
          for (final r in await db.select(db.gameScores).get()) r.toJson(),
        ],
        'settings': [
          for (final r in await db.select(db.settings).get()) r.toJson(),
        ],
      },
      'media': mediaData,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// Liest nur die Eckdaten (für die Rückfrage vor dem Ersetzen).
  BackupSummary inspect(Uint8List bytes) {
    final json = _decode(bytes);
    final tables = json['tables'] as Map<String, dynamic>;
    return BackupSummary(
      sets: (tables['sets'] as List).length,
      cards: (tables['cards'] as List).length,
      media: (json['media'] as Map).length,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  /// Ersetzt alle Daten durch die Sicherung.
  Future<BackupSummary> restore(Uint8List bytes) async {
    final json = _decode(bytes);
    final tables = json['tables'] as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String name) =>
        ((tables[name] as List?) ?? const []).cast<Map<String, dynamic>>();

    final oldCards = await db.select(db.cards).get();
    final oldDiagrams = await db.select(db.diagramPoints).get();

    await db.transaction(() async {
      for (final TableInfo t in [
        db.reviewLogs,
        db.reviewStates,
        db.gameScores,
        db.diagramPoints,
        db.cards,
        db.sets,
        db.folders,
        db.settings,
      ]) {
        await db.delete(t).go();
      }
      await db.batch((b) {
        b.insertAll(db.folders, rows('folders').map(Folder.fromJson));
        b.insertAll(db.sets, rows('sets').map(VocabSet.fromJson));
        b.insertAll(db.cards, rows('cards').map(VocabCard.fromJson));
        b.insertAll(
          db.diagramPoints,
          rows('diagramPoints').map(DiagramPoint.fromJson),
        );
        b.insertAll(
          db.reviewStates,
          rows('reviewStates').map(ReviewState.fromJson),
        );
        b.insertAll(db.reviewLogs, rows('reviewLogs').map(ReviewLog.fromJson));
        b.insertAll(db.gameScores, rows('gameScores').map(GameScore.fromJson));
        b.insertAll(db.settings, rows('settings').map(Setting.fromJson));
      });
    });

    // Alte Medien entfernen, gesicherte zurückschreiben.
    await media.deleteAll([
      for (final c in oldCards) ...[c.imagePath, c.audioPath],
      for (final d in oldDiagrams) d.imagePath,
    ]);
    final mediaData = (json['media'] as Map).cast<String, String>();
    for (final e in mediaData.entries) {
      await media.put(e.key, base64Decode(e.value));
    }
    return BackupSummary(
      sets: rows('sets').length,
      cards: rows('cards').length,
      media: mediaData.length,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> _decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const BackupException('Die Datei ist keine gültige Sicherung.');
    }
    if (json is! Map<String, dynamic> || json['format'] != format) {
      throw const BackupException(
        'Die Datei ist keine Sicherung von Barstardo Learning.',
      );
    }
    final schema = json['schema'] as int? ?? 0;
    if (schema > db.schemaVersion) {
      throw const BackupException(
        'Die Sicherung stammt aus einer neueren App-Version. Bitte zuerst die App aktualisieren.',
      );
    }
    if (json['tables'] is! Map) {
      throw const BackupException('Die Sicherung ist unvollständig.');
    }
    return json;
  }
}
