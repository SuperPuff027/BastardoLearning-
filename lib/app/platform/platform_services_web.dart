import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../data/database.dart';
import '../../data/media/db_media_store.dart';
import '../../data/vocab/vocab_open_web.dart';
import 'platform_services_common.dart';

export 'platform_services_common.dart';

/// Browser: Medien in der lokalen Datenbank, Vokabeldatenbank im Speicher.
Future<PlatformServices> createPlatformServices(AppDatabase db) async {
  // Bitte den Browser, die Daten nicht automatisch zu löschen (sofern
  // unterstützt). Export/Import bleibt trotzdem die sichere Variante.
  try {
    await web.window.navigator.storage.persist().toDart;
  } catch (_) {
    // nicht unterstützt
  }
  return PlatformServices(media: DbMediaStore(db), vocab: await loadVocabWeb());
}
