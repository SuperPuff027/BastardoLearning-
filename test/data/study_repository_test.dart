import 'package:barstardo_learning/core/learning/fsrs.dart';
import 'package:barstardo_learning/data/database.dart';
import 'package:barstardo_learning/data/study_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DateTime clock;
  late StudyRepository repo;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    clock = DateTime(2026, 3, 1, 9);
    repo = StudyRepository(db, clock: () => clock);
  });
  tearDown(() => db.close());

  Future<int> set(String title) => db
      .into(db.sets)
      .insert(SetsCompanion.insert(title: title, language: 'es'));
  Future<int> card(
    int setId,
    String f,
    String b, {
    bool starred = false,
    int pos = 0,
  }) => db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(
          setId: setId,
          front: f,
          back: b,
          starred: Value(starred),
          position: Value(pos),
        ),
      );

  test('loadCards respektiert Reihenfolge und „nur markierte“', () async {
    final s = await set('A');
    await card(s, 'dos', 'zwei', pos: 1);
    await card(s, 'uno', 'eins', pos: 0, starred: true);
    expect((await repo.loadCards(s)).map((c) => c.front), ['uno', 'dos']);
    expect((await repo.loadCards(s, starredOnly: true)).map((c) => c.front), [
      'uno',
    ]);
  });

  test('record schreibt FSRS-Zustand und Protokoll', () async {
    final s = await set('A');
    final c = await card(s, 'uno', 'eins');
    final m = await repo.record(
      cardId: c,
      mode: StudyMode.write,
      rating: Rating.good,
      responseMs: 1200,
    );
    expect(m.reps, 1);
    expect(m.due, clock.add(const Duration(days: 3)));

    final stored = await repo.memoryOf(c);
    expect(stored!.stability, closeTo(m.stability, 1e-9));

    final log = await db.select(db.reviewLogs).getSingle();
    expect(log.mode, StudyMode.write);
    expect(log.correct, isTrue);
    expect(log.rating, 3);
    expect(log.responseMs, 1200);

    clock = m.due;
    final m2 = await repo.record(
      cardId: c,
      mode: StudyMode.review,
      rating: Rating.good,
    );
    expect(m2.reps, 2);
    expect(m2.due.isAfter(clock.add(const Duration(days: 3))), isTrue);
  });

  test('pastErrors zählt falsche Antworten', () async {
    final s = await set('A');
    final a = await card(s, 'uno', 'eins');
    final b = await card(s, 'dos', 'zwei');
    await repo.record(cardId: a, mode: StudyMode.learn, rating: Rating.again);
    await repo.record(cardId: a, mode: StudyMode.learn, rating: Rating.again);
    await repo.record(cardId: b, mode: StudyMode.learn, rating: Rating.good);
    expect(await repo.pastErrors([a, b]), {a: 2});
  });

  test(
    'dueItems: fällige zuerst, dann neue (begrenzt), nicht fällige nicht',
    () async {
      final s = await set('A');
      final dueCard = await card(s, 'uno', 'eins', pos: 0);
      final notDue = await card(s, 'dos', 'zwei', pos: 1);
      await card(s, 'tres', 'drei', pos: 2);
      await card(s, 'cuatro', 'vier', pos: 3);

      await repo.record(
        cardId: dueCard,
        mode: StudyMode.review,
        rating: Rating.again,
      );
      await repo.record(
        cardId: notDue,
        mode: StudyMode.review,
        rating: Rating.easy,
      );
      clock = clock.add(const Duration(hours: 1));

      final items = await repo.dueItems(setId: s, newLimit: 1);
      expect(items.map((i) => i.card.front), ['uno', 'tres']);
      expect(items.first.memory, isNotNull);
      expect(items.last.memory, isNull);
    },
  );

  test('Übersicht zählt fällige und neue Karten pro Set', () async {
    final a = await set('A');
    final b = await set('B');
    final c1 = await card(a, 'uno', 'eins');
    await card(a, 'dos', 'zwei');
    await card(b, 'tres', 'drei');
    await repo.record(cardId: c1, mode: StudyMode.review, rating: Rating.again);
    clock = clock.add(const Duration(hours: 1));

    final summary = await repo.watchDueSummary().first;
    expect(summary.map((s) => (s.set.title, s.due, s.fresh)), [
      ('A', 1, 1),
      ('B', 0, 1),
    ]);
  });

  test('Migration von Schema 1: Spalte rating wird ergänzt', () async {
    final old = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE review_logs (id INTEGER PRIMARY KEY '
              'AUTOINCREMENT, card_id INTEGER NOT NULL, timestamp INTEGER NOT '
              'NULL, mode TEXT NOT NULL, correct INTEGER NOT NULL, '
              'response_ms INTEGER)',
            );
            raw.execute(
              "INSERT INTO review_logs (card_id, timestamp, mode, correct)"
              " VALUES (1, 0, 'write', 1)",
            );
            raw.execute('PRAGMA user_version = 1');
          },
        ),
        closeStreamsSynchronously: true,
      ),
    );
    final rows = await old.customSelect('SELECT * FROM review_logs').get();
    expect(rows.single.data.containsKey('rating'), isTrue);
    expect(rows.single.data['rating'], isNull);
    await old.close();
  });
}
