import 'package:flutter/services.dart';
import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart';

import 'vocab_repository.dart';

/// Lädt die mitgelieferte Vokabeldatenbank im Browser in den Speicher
/// (sqlite3 als WebAssembly, schreibgeschützt).
Future<VocabRepository> loadVocabWeb({AssetBundle? bundle}) async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final data = await (bundle ?? rootBundle).load(VocabRepository.assetPath);
  final fs = InMemoryFileSystem(name: 'vocab-memory');
  fs.fileData['/vocab.db'] = Uint8Buffer()
    ..addAll(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  sqlite.registerVirtualFileSystem(fs);
  return VocabRepository(
    sqlite.open('/vocab.db', vfs: 'vocab-memory', mode: OpenMode.readOnly),
  );
}
