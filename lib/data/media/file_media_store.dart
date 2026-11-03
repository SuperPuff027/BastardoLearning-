import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'media_store.dart';

/// Medien als Dateien im App-Verzeichnis (Android/iOS).
class FileMediaStore extends MediaStore {
  FileMediaStore(this.root);

  final Directory root;

  File resolve(String key) => File(p.join(root.path, key));

  @override
  Future<String> importBytes(
    Uint8List bytes, {
    required String extension,
    String folder = 'images',
  }) async {
    final key = p.join(folder, MediaStore.newName(extension));
    await put(key, bytes);
    return key;
  }

  @override
  Future<void> put(String key, Uint8List bytes) async {
    final file = resolve(key);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read(String? key) async {
    if (key == null) return null;
    final file = resolve(key);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String? key) async {
    if (key == null) return;
    final file = resolve(key);
    if (await file.exists()) await file.delete();
  }
}
