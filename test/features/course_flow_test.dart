import 'package:barstardo_learning/data/course_installer.dart';
import 'package:barstardo_learning/data/database.dart';
import 'package:barstardo_learning/data/library_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late TestEnv env;
  late LibraryRepository repo;
  late CourseInstaller installer;

  setUp(() async {
    env = await TestEnv.create();
    repo = LibraryRepository(env.db, env.media);
    installer = CourseInstaller(env.db, repo, sharedVocab);
  });
  tearDown(() => env.dispose());

  Future<List<String>> setTitles(String courseKey) async {
    final folder = await (env.db.select(
      env.db.folders,
    )..where((f) => f.courseKey.equals(courseKey))).getSingle();
    final sets =
        await (env.db.select(env.db.sets)
              ..where((s) => s.folderId.equals(folder.id))
              ..orderBy([(s) => OrderingTerm.asc(s.id)]))
            .get();
    return [for (final s in sets) s.title];
  }

  Future<int> cardCount(String courseKey) async {
    final folder = await (env.db.select(
      env.db.folders,
    )..where((f) => f.courseKey.equals(courseKey))).getSingle();
    final sets = await (env.db.select(
      env.db.sets,
    )..where((s) => s.folderId.equals(folder.id))).get();
    final cards = await (env.db.select(
      env.db.cards,
    )..where((c) => c.setId.isIn(sets.map((s) => s.id)))).get();
    return cards.length;
  }

  test('Kursdaten: Ordner, Reihenfolge und Umfang', () {
    final courses = sharedVocab.courses();
    expect(courses.map((c) => c.key), [
      'es_b1_aula3',
      'es_a2',
      'tr_uni_1_2',
      'tr_suffixe',
      'tr_a1',
      'tr_a2',
      'tr_b1_b2',
    ]);
    final byKey = {for (final c in courses) c.key: c};
    // Alle 2.079 Einträge aus „Wortschatz von A bis Z“ (Aula 3)
    expect(byKey['es_b1_aula3']!.cardCount, 2079);
    expect(byKey['es_b1_aula3']!.setCount, 12);
    // 806 Stichwörter + 277 Sätze + 51 Wortfeld-Wörter (Türkisch I + II)
    expect(byKey['tr_uni_1_2']!.cardCount, 1134);
    // Spanisch: nur A2 aus der Datenbank, kein A1-Ordner
    expect(courses.where((c) => c.language == 'es'), hasLength(2));
    expect(
      byKey['es_a2']!.cardCount,
      sharedVocab
          .presetGroups('es')
          .firstWhere((g) => g.cefrLevel == 'A2' && g.tag == null)
          .count,
    );
    // Türkisch: alle Wörter der Datenbank auf drei Niveau-Ordner verteilt
    final trLevels = ['tr_a1', 'tr_a2', 'tr_b1_b2'];
    expect(
      trLevels.fold(0, (s, k) => s + byKey[k]!.cardCount),
      sharedVocab.count('tr'),
    );
  });

  test('Aula 3: Unidad 1–12 mit Artikel und korrigierten Einträgen', () {
    final sets = sharedVocab.courseSets('es_b1_aula3');
    expect(sets.map((s) => s.title), [
      for (var i = 1; i <= 12; i++) 'Unidad $i',
    ]);
    final all = {for (final s in sets) ...s.cards};
    String back(String front) => all.firstWhere((c) => c.front == front).back;
    expect(back('el alga'), 'Alge'); // betontes a: el alga
    expect(back('el abanico'), 'Fächer');
    expect(back('dar (y) un beso'), 'einen Kuss geben');
    expect(back('hotel de x estrellas'), 'x-Sterne-Hotel');
    expect(all.any((c) => c.front.contains('saludos cordiales')), isTrue);
  });

  test('Türkisch I + II: Kasus-Hinweis und Sätze', () {
    final sets = sharedVocab.courseSets('tr_uni_1_2');
    final all = [for (final s in sets) ...s.cards];
    expect(
      all.any((c) => c.front == '(+İ) açmak' && c.back == '… öffnen'),
      isTrue,
    );
    expect(
      all.any((c) => c.front == 'Açım.' && c.back == 'Ich habe Hunger.'),
      isTrue,
    );
    expect(sets.map((s) => s.title), contains('Wortfeld: die Zahlen'));
    expect(
      all.lastWhere((c) => c.front == 'babaanne').back,
      'die Oma (väterlicherseits)',
    );
  });

  test('Suffix-Ordner: Regeln, Fälle, Zeiten und Kombinationen', () {
    final sets = sharedVocab.courseSets('tr_suffixe');
    expect(sets.first.title, 'Lautregeln');
    expect(
      sets.map((s) => s.title),
      containsAll(['Fälle (Kasus)', 'Präsens -Iyor', 'Partizip & Nebensatz']),
    );
    final all = {
      for (final s in sets)
        for (final c in s.cards) c.front: c.back,
    };
    // Türkisch vorne: Endung + türkische Beispiele
    // Deutsch hinten: Name + deutsche Beispiele (keine Endung)
    expect(
      all['-DA: evde, okulda, kitapta'],
      'Lokativ (wo?): zu Hause, in der Schule, im Buch',
    );
    expect(
      all['evlerimizde (ev + ler + imiz + de)'],
      'in unseren Häusern (Plural + unser + Lokativ)',
    );
    for (final back in all.values) {
      expect(back, isNot(matches(RegExp(r'(^|[ (])-[A-Za-z(]'))));
    }
  });

  test('Geänderter Kurs wird aktualisiert, Lernstand bleibt', () async {
    await installer.installNew();
    final folder = (await repo.getFolders()).firstWhere(
      (f) => f.folder.courseKey == 'tr_suffixe',
    );
    final set =
        (await (env.db.select(env.db.sets)
                  ..where((s) => s.folderId.equals(folder.folder.id))
                  ..orderBy([(s) => OrderingTerm.asc(s.id)]))
                .get())
            .first;
    final card = await (env.db.select(
      env.db.cards,
    )..where((c) => c.setId.equals(set.id) & c.position.equals(0))).getSingle();
    // alten Stand simulieren: anderer Text, Version 1, schon gelernt
    await (env.db.update(env.db.cards)..where((c) => c.id.equals(card.id)))
        .write(const CardsCompanion(front: Value('alt'), back: Value('alt')));
    await env.db
        .into(env.db.reviewStates)
        .insert(
          ReviewStatesCompanion.insert(
            cardId: Value(card.id),
            due: DateTime(2030),
          ),
        );
    await env.db.writeSetting(CourseInstaller.versionKey, 'tr_suffixe:1');

    expect(await installer.installNew(), 0);
    final updated = await (env.db.select(
      env.db.cards,
    )..where((c) => c.id.equals(card.id))).getSingle();
    expect(updated.front, startsWith('A = a / e'));
    expect(updated.back, startsWith('kleine Vokalharmonie'));
    expect(await env.db.select(env.db.reviewStates).get(), hasLength(1));
    expect(
      await env.db.readSetting(CourseInstaller.versionKey),
      contains('tr_suffixe:2'),
    );
  });

  test('Neuer Kurs kommt bei bestehenden Nutzern dazu', () async {
    // Stand vor dem Suffix-Ordner: alle anderen Kurse schon angelegt
    await env.db.writeSetting(
      CourseInstaller.settingKey,
      'es_b1_aula3,es_a2,tr_uni_1_2,tr_a1,tr_a2,tr_b1_b2',
    );
    expect(await installer.installNew(), 1);
    final folders = await repo.getFolders();
    expect(folders.single.folder.name, 'Türkisch Suffixe');
  });

  test('Kurse werden einmal angelegt und bleiben gelöscht', () async {
    expect(await installer.installNew(), 7);
    expect(await installer.installNew(), 0);
    expect(await cardCount('es_b1_aula3'), 2079);
    expect((await setTitles('es_b1_aula3')).first, 'Unidad 1');

    final folders = await repo.getFolders();
    expect(folders.first.folder.name, 'Spanisch B1 – Aula 3');
    expect(folders.first.cardCount, 2079);
    expect(folders.first.setCount, 12);

    // Gelöschter Kursordner kommt nicht von selbst zurück …
    final aula = folders.first.folder;
    await repo.deleteFolder(aula.id, deleteSets: true);
    expect(await installer.installNew(), 0);
    expect((await installer.missing()).map((c) => c.key), ['es_b1_aula3']);
    // … lässt sich aber zurückholen.
    await installer.install('es_b1_aula3');
    expect(await installer.missing(), isEmpty);
    expect(await cardCount('es_b1_aula3'), 2079);
  });

  testWidgets('Kursordner oben, Sprachfilter und Buchreihenfolge', (
    tester,
  ) async {
    await tester.runAsync(installer.installNew);
    await repo.createFolder('Mein Ordner');
    await env.pumpApp(tester);

    expect(find.text('Kurse'), findsOneWidget);
    expect(find.text('Spanisch B1 – Aula 3'), findsOneWidget);
    expect(find.text('12 Sets · 2079 Karten'), findsOneWidget);
    expect(find.text('Eigene Ordner', skipOffstage: false), findsOneWidget);

    await tester.tap(find.byKey(const Key('courseFilter_tr')));
    await tester.pumpAndSettle();
    expect(find.text('Spanisch B1 – Aula 3'), findsNothing);
    expect(find.text('Türkisch I + II (Uni)'), findsOneWidget);
    expect(find.text('Türkisch B1/B2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('courseFilter_es')));
    await tester.pumpAndSettle();
    expect(find.text('Türkisch A1'), findsNothing);
    await tester.tap(find.byKey(const Key('course_es_b1_aula3')));
    await tester.pumpAndSettle();
    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles.take(3), ['Unidad 1', 'Unidad 2', 'Unidad 3']);
  });

  testWidgets('Gelöschten Kursordner über „Neu“ zurückholen', (tester) async {
    await tester.runAsync(installer.installNew);
    final folders = await repo.getFolders();
    final a2 = folders.firstWhere((f) => f.folder.courseKey == 'es_a2');
    await repo.deleteFolder(a2.folder.id, deleteSets: true);
    await env.pumpApp(tester);
    expect(find.text('Spanisch A2'), findsNothing);

    await tester.tap(find.byKey(const Key('libraryAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createCourse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addCourse_es_a2')));
    await settleIo(tester);
    expect(find.text('Spanisch A2'), findsOneWidget); // Ordner geöffnet
    expect(find.text('Essen & Trinken'), findsOneWidget);
  });
}
