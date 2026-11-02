import 'package:drift/drift.dart';

import '../core/learning/fsrs.dart';
import '../core/learning/study_item.dart';
import 'database.dart';

/// Lernmodi für das Protokoll.
abstract final class StudyMode {
  static const flashcards = 'flashcards';
  static const write = 'write';
  static const learn = 'learn';
  static const test = 'test';
  static const review = 'review';
}

class DueSummary {
  const DueSummary(this.set, this.due, this.fresh);

  final VocabSet set;

  /// Fällige Wiederholungen.
  final int due;

  /// Noch nie gelernte Karten.
  final int fresh;
}

/// Karte mit FSRS-Zustand für die Wiederholung.
class ReviewItem {
  const ReviewItem(this.card, this.memory);

  final StudyCard card;
  final CardMemory? memory;
}

/// Lernfortschritt: FSRS-Zustand und Protokoll.
class StudyRepository {
  StudyRepository(
    this.db, {
    this.fsrs = const Fsrs(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final Fsrs fsrs;
  final DateTime Function() _clock;

  DateTime now() => _clock();

  static StudyCard toStudyCard(VocabCard c) => StudyCard(
    id: c.id,
    front: c.front,
    back: c.back,
    frontRich: c.frontRich,
    backRich: c.backRich,
    imagePath: c.imagePath,
    starred: c.starred,
  );

  static CardMemory toMemory(ReviewState s) => CardMemory(
    due: s.due,
    stability: s.stability,
    difficulty: s.difficulty,
    reps: s.reps,
    lapses: s.lapses,
    lastReview: s.lastReview,
  );

  Future<List<StudyCard>> loadCards(
    int setId, {
    bool starredOnly = false,
  }) async {
    final q = db.select(db.cards)
      ..where((c) => c.setId.equals(setId))
      ..orderBy([
        (c) => OrderingTerm.asc(c.position),
        (c) => OrderingTerm.asc(c.id),
      ]);
    if (starredOnly) q.where((c) => c.starred.equals(true));
    return (await q.get()).map(toStudyCard).toList();
  }

  /// Anzahl falscher Antworten pro Karte (für den adaptiven Modus).
  Future<Map<int, int>> pastErrors(Iterable<int> cardIds) async {
    final ids = cardIds.toList();
    if (ids.isEmpty) return {};
    final count = db.reviewLogs.id.count();
    final rows =
        await (db.selectOnly(db.reviewLogs)
              ..addColumns([db.reviewLogs.cardId, count])
              ..where(
                db.reviewLogs.cardId.isIn(ids) &
                    db.reviewLogs.correct.equals(false),
              )
              ..groupBy([db.reviewLogs.cardId]))
            .get();
    return {
      for (final r in rows) r.read(db.reviewLogs.cardId)!: r.read(count) ?? 0,
    };
  }

  Future<CardMemory?> memoryOf(int cardId) async {
    final s = await (db.select(
      db.reviewStates,
    )..where((r) => r.cardId.equals(cardId))).getSingleOrNull();
    return s == null ? null : toMemory(s);
  }

  /// Speichert eine Antwort: FSRS-Zustand aktualisieren und protokollieren.
  Future<CardMemory> record({
    required int cardId,
    required String mode,
    required Rating rating,
    bool? correct,
    int? responseMs,
  }) {
    final at = now();
    return db.transaction(() async {
      final memory = fsrs.review(await memoryOf(cardId), rating, at);
      await db
          .into(db.reviewStates)
          .insertOnConflictUpdate(
            ReviewStatesCompanion.insert(
              cardId: Value(cardId),
              due: memory.due,
              stability: Value(memory.stability),
              difficulty: Value(memory.difficulty),
              reps: Value(memory.reps),
              lapses: Value(memory.lapses),
              lastReview: Value(memory.lastReview),
            ),
          );
      await db
          .into(db.reviewLogs)
          .insert(
            ReviewLogsCompanion.insert(
              cardId: cardId,
              mode: mode,
              correct: correct ?? rating != Rating.again,
              rating: Value(rating.value),
              responseMs: Value(responseMs),
              timestamp: Value(at),
            ),
          );
      return memory;
    });
  }

  /// Karten für eine Wiederholungssitzung: zuerst fällige (älteste zuerst),
  /// dann bis zu [newLimit] neue Karten.
  Future<List<ReviewItem>> dueItems({int? setId, int newLimit = 20}) async {
    final at = now();
    final dueQuery =
        db.select(db.cards).join([
            innerJoin(
              db.reviewStates,
              db.reviewStates.cardId.equalsExp(db.cards.id),
            ),
          ])
          ..where(db.reviewStates.due.isSmallerOrEqualValue(at))
          ..orderBy([OrderingTerm.asc(db.reviewStates.due)]);
    if (setId != null) dueQuery.where(db.cards.setId.equals(setId));
    final due = [
      for (final r in await dueQuery.get())
        ReviewItem(
          toStudyCard(r.readTable(db.cards)),
          toMemory(r.readTable(db.reviewStates)),
        ),
    ];

    final freshQuery =
        db.select(db.cards).join([
            leftOuterJoin(
              db.reviewStates,
              db.reviewStates.cardId.equalsExp(db.cards.id),
            ),
          ])
          ..where(db.reviewStates.cardId.isNull())
          ..orderBy([
            OrderingTerm.asc(db.cards.setId),
            OrderingTerm.asc(db.cards.position),
          ])
          ..limit(newLimit);
    if (setId != null) freshQuery.where(db.cards.setId.equals(setId));
    final fresh = [
      for (final r in await freshQuery.get())
        ReviewItem(toStudyCard(r.readTable(db.cards)), null),
    ];
    return [...due, ...fresh];
  }

  /// Übersicht pro Set: fällige und neue Karten.
  Stream<List<DueSummary>> watchDueSummary() {
    final at = now();
    final dueExpr = db.reviewStates.due.isSmallerOrEqualValue(at);
    final dueCount = db.cards.id.count(filter: dueExpr);
    final freshCount = db.cards.id.count(
      filter: db.reviewStates.cardId.isNull(),
    );
    final query =
        db.select(db.sets).join([
            leftOuterJoin(db.cards, db.cards.setId.equalsExp(db.sets.id)),
            leftOuterJoin(
              db.reviewStates,
              db.reviewStates.cardId.equalsExp(db.cards.id),
            ),
          ])
          ..addColumns([dueCount, freshCount])
          ..groupBy([db.sets.id])
          ..orderBy([OrderingTerm.asc(db.sets.title.collate(Collate.noCase))]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          DueSummary(
            r.readTable(db.sets),
            r.read(dueCount) ?? 0,
            r.read(freshCount) ?? 0,
          ),
      ],
    );
  }
}
