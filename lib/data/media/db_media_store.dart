import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../database.dart';
import 'media_store.dart';

/// Medien in der lokalen Datenbank (Browser – dort gibt es keine Dateien).
class DbMediaStore extends MediaStore {
  DbMediaStore(this.db);

  final AppDatabase db;

  @override
  Future<String> importBytes(
    Uint8List bytes, {
    required String extension,
    String folder = 'images',
  }) async {
    final key = '$folder/${MediaStore.newName(extension)}';
    await put(key, bytes);
    return key;
  }

  @override
  Future<void> put(String key, Uint8List bytes) => db
      .into(db.mediaBlobs)
      .insertOnConflictUpdate(
        MediaBlobsCompanion.insert(key: key, data: bytes),
      );

  @override
  Future<Uint8List?> read(String? key) async {
    if (key == null) return null;
    final row = await (db.select(
      db.mediaBlobs,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    return row?.data;
  }

  @override
  Future<void> delete(String? key) async {
    if (key == null) return;
    await (db.delete(db.mediaBlobs)..where((m) => m.key.equals(key))).go();
  }
}
