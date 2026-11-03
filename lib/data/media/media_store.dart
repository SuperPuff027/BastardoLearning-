import 'dart:typed_data';

/// Ablage für Bilder (später Audio).
///
/// In der Datenbank stehen nur Schlüssel (z. B. `images/…jpg`). Auf dem
/// Handy sind das Dateien im App-Verzeichnis ([FileMediaStore]), im Browser
/// Einträge in der lokalen Datenbank ([DbMediaStore]).
abstract class MediaStore {
  /// Speichert [bytes] und gibt den neuen Schlüssel zurück.
  Future<String> importBytes(
    Uint8List bytes, {
    required String extension,
    String folder = 'images',
  });

  /// Inhalt zu [key] oder `null`, wenn nicht vorhanden.
  Future<Uint8List?> read(String? key);

  /// Legt unter genau diesem Schlüssel ab (für die Wiederherstellung).
  Future<void> put(String key, Uint8List bytes);

  Future<void> delete(String? key);

  /// Unabhängige Kopie (z. B. beim Kopieren eines Sets).
  Future<String?> duplicate(String? key) async {
    if (key == null) return null;
    final bytes = await read(key);
    if (bytes == null) return null;
    final dot = key.lastIndexOf('.');
    final slash = key.indexOf('/');
    return importBytes(
      bytes,
      extension: dot > slash ? key.substring(dot) : '',
      folder: slash > 0 ? key.substring(0, slash) : 'images',
    );
  }

  Future<void> deleteAll(Iterable<String?> keys) async {
    for (final k in keys) {
      await delete(k);
    }
  }

  static int _counter = 0;

  /// Eindeutiger Dateiname.
  static String newName(String extension) {
    final ext = extension.isEmpty || extension.startsWith('.')
        ? extension.toLowerCase()
        : '.${extension.toLowerCase()}';
    return '${DateTime.now().microsecondsSinceEpoch}_${_counter++}$ext';
  }
}

/// Ein ausgewähltes Bild (Kamera/Galerie), plattformunabhängig.
class PickedImage {
  const PickedImage({required this.bytes, required this.name, this.path});

  final Uint8List bytes;
  final String name;

  /// Dateipfad auf dem Gerät (für die Texterkennung auf dem Handy).
  final String? path;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot) : '.jpg';
  }
}
