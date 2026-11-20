import 'database.dart';
import 'library_repository.dart';
import 'vocab/vocab_repository.dart';

/// Legt die mitgelieferten Kursordner (Lehrbuch- und Niveau-Wortschatz)
/// in der Bibliothek an.
///
/// Jeder Kurs wird nur einmal automatisch angelegt. Löscht der Nutzer den
/// Ordner, bleibt er weg, bis er ihn über „Kursordner hinzufügen“ zurückholt.
class CourseInstaller {
  CourseInstaller(this.db, this.library, this.vocab);

  static const settingKey = 'installed_courses';

  final AppDatabase db;
  final LibraryRepository library;
  final VocabRepository vocab;

  Future<Set<String>> _installed() async {
    final raw = await db.readSetting(settingKey) ?? '';
    return raw.split(',').where((k) => k.isNotEmpty).toSet();
  }

  /// Legt alle Kurse an, die noch nie angelegt wurden. Gibt die Anzahl zurück.
  Future<int> installNew() async {
    final installed = await _installed();
    final present = await library.presentCourseKeys();
    // Reihenfolge vorhandener Kursordner an neue Kurse anpassen
    await library.updateCoursePositions({
      for (final c in vocab.courses()) c.key: c.position,
    });
    var n = 0;
    for (final c in vocab.courses()) {
      if (installed.contains(c.key)) continue;
      if (!present.contains(c.key)) {
        await _install(c);
        n++;
      }
      installed.add(c.key);
      await db.writeSetting(settingKey, installed.join(','));
    }
    return n;
  }

  /// Kurse, deren Ordner gerade nicht in der Bibliothek ist.
  Future<List<CourseInfo>> missing() async {
    final present = await library.presentCourseKeys();
    return [
      for (final c in vocab.courses())
        if (!present.contains(c.key)) c,
    ];
  }

  /// Legt einen Kurs (wieder) an und gibt die Ordner-ID zurück.
  Future<int> install(String key) async {
    final course = vocab.courses().firstWhere((c) => c.key == key);
    final id = await _install(course);
    final installed = await _installed()
      ..add(key);
    await db.writeSetting(settingKey, installed.join(','));
    return id;
  }

  Future<int> _install(CourseInfo c) => library.installCourse(
    key: c.key,
    title: c.title,
    language: c.language,
    position: c.position,
    sets: [
      for (final s in vocab.courseSets(c.key))
        (
          title: s.title,
          cards: [
            for (final card in s.cards)
              VocabCardData(
                front: card.front,
                back: card.back,
                vocabId: card.vocabId,
                verified: true,
              ),
          ],
        ),
    ],
  );
}
