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

  /// Inhaltsversion je angelegtem Kurs, z. B. `tr_suffixe:2,es_a2:1`.
  static const versionKey = 'course_versions';

  final AppDatabase db;
  final LibraryRepository library;
  final VocabRepository vocab;

  Future<Map<String, int>> _versions() async {
    final raw = await db.readSetting(versionKey) ?? '';
    return {
      for (final e in raw.split(','))
        if (e.contains(':'))
          e.split(':').first: int.tryParse(e.split(':').last) ?? 1,
    };
  }

  Future<void> _setVersion(String key, int version) async {
    final v = await _versions()
      ..[key] = version;
    await db.writeSetting(
      versionKey,
      [for (final e in v.entries) '${e.key}:${e.value}'].join(','),
    );
  }

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
    // Vorhandene Kursordner mit neuerer Inhaltsversion aktualisieren
    final versions = await _versions();
    for (final c in vocab.courses()) {
      if (present.contains(c.key) && (versions[c.key] ?? 1) < c.version) {
        await library.syncCourse(c.key, _sets(c.key));
        await _setVersion(c.key, c.version);
      }
    }
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

  Future<int> _install(CourseInfo c) async {
    final id = await library.installCourse(
      key: c.key,
      title: c.title,
      language: c.language,
      position: c.position,
      sets: _sets(c.key),
    );
    await _setVersion(c.key, c.version);
    return id;
  }

  List<({String title, List<VocabCardData> cards})> _sets(String key) => [
    for (final s in vocab.courseSets(key))
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
  ];
}
