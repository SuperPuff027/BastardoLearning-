import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Legt Medien (Bilder, später Audio) als Dateien im App-Verzeichnis ab.
///
/// In der Datenbank stehen nur relative Pfade (z. B. `images/…jpg`), weil
/// sich der absolute Pfad des App-Containers auf iOS bei Updates ändert.
class MediaStore {
  MediaStore(this.root);

  final Directory root;
  final _random = Random();

  File resolve(String relativePath) => File(p.join(root.path, relativePath));

  /// Kopiert [source] in den Ordner [folder] und gibt den relativen Pfad zurück.
  Future<String> import(File source, {String folder = 'images'}) async {
    final ext = p.extension(source.path).toLowerCase();
    final rel = p.join(folder, '${_newName()}$ext');
    final target = resolve(rel);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return rel;
  }

  /// Legt eine unabhängige Kopie an (z. B. beim Kopieren eines Sets).
  Future<String?> duplicate(String? relativePath) async {
    if (relativePath == null) return null;
    final source = resolve(relativePath);
    if (!await source.exists()) return null;
    return import(source, folder: p.dirname(relativePath));
  }

  Future<void> delete(String? relativePath) async {
    if (relativePath == null) return;
    final file = resolve(relativePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll(Iterable<String?> relativePaths) async {
    for (final path in relativePaths) {
      await delete(path);
    }
  }

  String _newName() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32).toRadixString(16)}';
}
