import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database.dart';
import '../../data/media/file_media_store.dart';
import '../../data/vocab/vocab_open_io.dart';
import 'platform_services_common.dart';

export 'platform_services_common.dart';

/// Handy: Medien als Dateien, Vokabeldatenbank als Datei im App-Verzeichnis.
Future<PlatformServices> createPlatformServices(AppDatabase db) async {
  final docs = await getApplicationDocumentsDirectory();
  final support = await getApplicationSupportDirectory();
  return PlatformServices(
    media: FileMediaStore(Directory(p.join(docs.path, 'media'))),
    vocab: await installVocab(Directory(p.join(support.path, 'vocab'))),
  );
}
