import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'vocab_repository.dart';

/// Öffnet eine vorhandene Datei schreibgeschützt (Handy, Tests, Werkzeuge).
VocabRepository openVocabFile(String path) =>
    VocabRepository(sqlite3.open(path, mode: OpenMode.readOnly));

/// Kopiert die Datenbank aus den Assets nach [directory] (nur wenn sie fehlt
/// oder sich geändert hat) und öffnet sie.
Future<VocabRepository> installVocab(
  Directory directory, {
  AssetBundle? bundle,
}) async {
  final data = await (bundle ?? rootBundle).load(VocabRepository.assetPath);
  final file = File(p.join(directory.path, 'vocab.db'));
  if (!await file.exists() || await file.length() != data.lengthInBytes) {
    await directory.create(recursive: true);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }
  return openVocabFile(file.path);
}
