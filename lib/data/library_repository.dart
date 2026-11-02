import 'package:drift/drift.dart';

import '../core/import_parser.dart';
import '../core/rich_text.dart';
import 'database.dart';
import 'media/media_store.dart';

class FolderWithCount {
  const FolderWithCount(this.folder, this.setCount);

  final Folder folder;
  final int setCount;
}

class SetWithCount {
  const SetWithCount(this.set, this.cardCount);

  final VocabSet set;
  final int cardCount;
}

/// Inhalt einer Karte beim Anlegen oder Bearbeiten.
class CardDraft {
  const CardDraft({
    required this.front,
    required this.back,
    this.imagePath,
    this.starred = false,
  });

  final RichDocument front;
  final RichDocument back;
  final String? imagePath;
  final bool starred;
}

class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ordner, Sets und Karten: alles, was der Nutzer manuell verwaltet.
class LibraryRepository {
  LibraryRepository(this.db, this.media);

  final AppDatabase db;
  final MediaStore media;

  // ---------------------------------------------------------------- Ordner

  Stream<List<FolderWithCount>> watchFolders() {
    final (query, map) = _foldersQuery();
    return query.watch().map(map);
  }

  Future<List<FolderWithCount>> getFolders() async {
    final (query, map) = _foldersQuery();
    return map(await query.get());
  }

  (JoinedSelectStatement, List<FolderWithCount> Function(List<TypedResult>))
  _foldersQuery() {
    final count = db.sets.id.count();
    final query =
        db.select(db.folders).join([
            leftOuterJoin(db.sets, db.sets.folderId.equalsExp(db.folders.id)),
          ])
          ..addColumns([count])
          ..groupBy([db.folders.id])
          ..orderBy([
            OrderingTerm.asc(db.folders.name.collate(Collate.noCase)),
          ]);
    return (
      query,
      (rows) => [
        for (final r in rows)
          FolderWithCount(r.readTable(db.folders), r.read(count) ?? 0),
      ],
    );
  }

  Stream<Folder?> watchFolder(int id) => (db.select(
    db.folders,
  )..where((f) => f.id.equals(id))).watchSingleOrNull();

  Future<int> createFolder(String name) async => db
      .into(db.folders)
      .insert(FoldersCompanion.insert(name: _requireName(name, 'Ordnername')));

  Future<void> renameFolder(int id, String name) async =>
      (db.update(db.folders)..where((f) => f.id.equals(id))).write(
        FoldersCompanion(name: Value(_requireName(name, 'Ordnername'))),
      );

  /// Löscht den Ordner. Die Sets darin bleiben erhalten und landen
  /// wieder in „Alle Sets“, außer [deleteSets] ist gesetzt.
  Future<void> deleteFolder(int id, {bool deleteSets = false}) async {
    if (deleteSets) {
      final ids =
          await (db.selectOnly(db.sets)
                ..addColumns([db.sets.id])
                ..where(db.sets.folderId.equals(id)))
              .map((r) => r.read(db.sets.id)!)
              .get();
      for (final setId in ids) {
        await deleteSet(setId);
      }
    }
    await (db.delete(db.folders)..where((f) => f.id.equals(id))).go();
  }

  // ------------------------------------------------------------------ Sets

  /// Sets eines Ordners; ohne [folderId] die Sets ohne Ordner.
  Stream<List<SetWithCount>> watchSets({int? folderId}) {
    final (query, map) = _setsQuery(
      (s) =>
          folderId == null ? s.folderId.isNull() : s.folderId.equals(folderId),
    );
    return query.watch().map(map);
  }

  Stream<List<SetWithCount>> watchAllSets() {
    final (query, map) = _setsQuery(null);
    return query.watch().map(map);
  }

  Future<List<SetWithCount>> getAllSets() async {
    final (query, map) = _setsQuery(null);
    return map(await query.get());
  }

  (JoinedSelectStatement, List<SetWithCount> Function(List<TypedResult>))
  _setsQuery(Expression<bool> Function($SetsTable s)? filter) {
    final count = db.cards.id.count();
    final query =
        db.select(db.sets).join([
            leftOuterJoin(db.cards, db.cards.setId.equalsExp(db.sets.id)),
          ])
          ..addColumns([count])
          ..groupBy([db.sets.id])
          ..orderBy([
            OrderingTerm.desc(db.sets.createdAt),
            OrderingTerm.desc(db.sets.id),
          ]);
    if (filter != null) query.where(filter(db.sets));
    return (
      query,
      (rows) => [
        for (final r in rows)
          SetWithCount(r.readTable(db.sets), r.read(count) ?? 0),
      ],
    );
  }

  Stream<VocabSet?> watchSet(int id) =>
      (db.select(db.sets)..where((s) => s.id.equals(id))).watchSingleOrNull();

  Future<VocabSet?> getSet(int id) =>
      (db.select(db.sets)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> createSet({
    required String title,
    required String language,
    int? folderId,
    bool ttsEnabled = false,
  }) => db
      .into(db.sets)
      .insert(
        SetsCompanion.insert(
          title: _requireName(title, 'Titel'),
          language: language,
          folderId: Value(folderId),
          ttsEnabled: Value(ttsEnabled),
        ),
      );

  Future<void> updateSet(
    int id, {
    required String title,
    required String language,
    required int? folderId,
    required bool ttsEnabled,
  }) async => (db.update(db.sets)..where((s) => s.id.equals(id))).write(
    SetsCompanion(
      title: Value(_requireName(title, 'Titel')),
      language: Value(language),
      folderId: Value(folderId),
      ttsEnabled: Value(ttsEnabled),
    ),
  );

  Future<void> moveSetToFolder(int setId, int? folderId) =>
      (db.update(db.sets)..where((s) => s.id.equals(setId))).write(
        SetsCompanion(folderId: Value(folderId)),
      );

  Future<void> deleteSet(int id) async {
    final media = await _mediaOfSet(id);
    await (db.delete(db.sets)..where((s) => s.id.equals(id))).go();
    await this.media.deleteAll(media);
  }

  /// Kopiert ein Set mit allen Karten. Bilder werden mitkopiert, der
  /// Lernfortschritt nicht. Gibt die ID des neuen Sets zurück.
  Future<int> copySet(int id) async {
    final source = await getSet(id);
    if (source == null) throw const ValidationException('Set nicht gefunden');
    final cards = await _cardsOf(id);
    final copies = await _duplicateMedia(cards);
    return db.transaction(() async {
      final newId = await db
          .into(db.sets)
          .insert(
            SetsCompanion.insert(
              title: '${source.title} (Kopie)',
              language: source.language,
              folderId: Value(source.folderId),
              ttsEnabled: Value(source.ttsEnabled),
              goalDate: Value(source.goalDate),
            ),
          );
      await _insertCopies(newId, copies, startPosition: 0);
      return newId;
    });
  }

  /// Führt [sourceIds] in [targetId] zusammen. Die Karten werden kopiert;
  /// mit [deleteSources] werden die Quell-Sets danach gelöscht (dann werden
  /// die Karten samt Lernfortschritt verschoben statt kopiert).
  /// Gibt die Anzahl übernommener Karten zurück.
  Future<int> mergeSets(
    int targetId,
    List<int> sourceIds, {
    bool deleteSources = false,
  }) async {
    final target = await getSet(targetId);
    if (target == null) throw const ValidationException('Set nicht gefunden');
    final sources = sourceIds.where((id) => id != targetId).toSet().toList();
    for (final id in sources) {
      final s = await getSet(id);
      if (s == null) throw const ValidationException('Set nicht gefunden');
      if (s.language != target.language) {
        throw const ValidationException(
          'Nur Sets mit derselben Sprache können zusammengeführt werden',
        );
      }
    }

    var moved = 0;
    if (deleteSources) {
      await db.transaction(() async {
        var position = await _nextPosition(targetId);
        for (final id in sources) {
          for (final card in await _cardsOf(id)) {
            await (db.update(
              db.cards,
            )..where((c) => c.id.equals(card.id))).write(
              CardsCompanion(
                setId: Value(targetId),
                position: Value(position++),
              ),
            );
            moved++;
          }
          await (db.delete(db.sets)..where((s) => s.id.equals(id))).go();
        }
      });
      return moved;
    }

    final all = <VocabCard>[];
    for (final id in sources) {
      all.addAll(await _cardsOf(id));
    }
    final copies = await _duplicateMedia(all);
    await db.transaction(() async {
      await _insertCopies(
        targetId,
        copies,
        startPosition: await _nextPosition(targetId),
      );
    });
    return copies.length;
  }

  // ---------------------------------------------------------------- Karten

  Stream<List<VocabCard>> watchCards(int setId, {bool starredOnly = false}) {
    final q = db.select(db.cards)
      ..where((c) => c.setId.equals(setId))
      ..orderBy([
        (c) => OrderingTerm.asc(c.position),
        (c) => OrderingTerm.asc(c.id),
      ]);
    if (starredOnly) q.where((c) => c.starred.equals(true));
    return q.watch();
  }

  /// Karten-ID → Set-ID.
  Future<Map<int, int>> setIdsOfCards(Iterable<int> cardIds) async {
    final ids = cardIds.toList();
    if (ids.isEmpty) return {};
    final rows =
        await (db.selectOnly(db.cards)
              ..addColumns([db.cards.id, db.cards.setId])
              ..where(db.cards.id.isIn(ids)))
            .get();
    return {
      for (final r in rows) r.read(db.cards.id)!: r.read(db.cards.setId)!,
    };
  }

  Future<VocabCard?> getCard(int id) =>
      (db.select(db.cards)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> addCard(int setId, CardDraft draft) async {
    final c = _validated(draft);
    return db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            setId: setId,
            front: c.front.plainText,
            back: c.back.plainText,
            frontRich: Value(c.front.encode()),
            backRich: Value(c.back.encode()),
            imagePath: Value(c.imagePath),
            starred: Value(c.starred),
            position: Value(await _nextPosition(setId)),
          ),
        );
  }

  /// Speichert die Karte. Manuell bearbeitete Karten gelten als bestätigt.
  /// Ein ersetztes oder entferntes Bild wird gelöscht.
  Future<void> updateCard(int id, CardDraft draft) async {
    final c = _validated(draft);
    final old = await getCard(id);
    await (db.update(db.cards)..where((card) => card.id.equals(id))).write(
      CardsCompanion(
        front: Value(c.front.plainText),
        back: Value(c.back.plainText),
        frontRich: Value(c.front.encode()),
        backRich: Value(c.back.encode()),
        imagePath: Value(c.imagePath),
        starred: Value(c.starred),
        verified: const Value(true),
      ),
    );
    if (old?.imagePath != null && old!.imagePath != c.imagePath) {
      await media.delete(old.imagePath);
    }
  }

  Future<void> setStarred(int cardId, bool starred) =>
      (db.update(db.cards)..where((c) => c.id.equals(cardId))).write(
        CardsCompanion(starred: Value(starred)),
      );

  Future<void> deleteCard(int id) async {
    final card = await getCard(id);
    await (db.delete(db.cards)..where((c) => c.id.equals(id))).go();
    await media.deleteAll([card?.imagePath, card?.audioPath]);
  }

  /// Fügt importierte Paare als Karten an das Set an.
  Future<int> importCards(int setId, List<ImportedPair> pairs) async {
    if (pairs.isEmpty) return 0;
    await db.transaction(() async {
      var position = await _nextPosition(setId);
      await db.batch((b) {
        b.insertAll(db.cards, [
          for (final p in pairs)
            CardsCompanion.insert(
              setId: setId,
              front: p.front,
              back: p.back,
              position: Value(position++),
            ),
        ]);
      });
    });
    return pairs.length;
  }

  // ---------------------------------------------------------------- intern

  Future<List<VocabCard>> _cardsOf(int setId) =>
      (db.select(db.cards)
            ..where((c) => c.setId.equals(setId))
            ..orderBy([
              (c) => OrderingTerm.asc(c.position),
              (c) => OrderingTerm.asc(c.id),
            ]))
          .get();

  Future<int> _nextPosition(int setId) async {
    final max = db.cards.position.max();
    final row =
        await (db.selectOnly(db.cards)
              ..addColumns([max])
              ..where(db.cards.setId.equals(setId)))
            .getSingle();
    final value = row.read(max);
    return value == null ? 0 : value + 1;
  }

  Future<List<String?>> _mediaOfSet(int setId) async {
    final cards = await _cardsOf(setId);
    final diagrams = await (db.select(
      db.diagramPoints,
    )..where((d) => d.setId.equals(setId))).get();
    return [
      for (final c in cards) ...[c.imagePath, c.audioPath],
      for (final d in diagrams) d.imagePath,
    ];
  }

  Future<List<VocabCard>> _duplicateMedia(List<VocabCard> cards) async => [
    for (final c in cards)
      c.copyWith(
        imagePath: Value(await media.duplicate(c.imagePath)),
        audioPath: Value(await media.duplicate(c.audioPath)),
      ),
  ];

  Future<void> _insertCopies(
    int setId,
    List<VocabCard> cards, {
    required int startPosition,
  }) async {
    var position = startPosition;
    await db.batch((b) {
      b.insertAll(db.cards, [
        for (final c in cards)
          CardsCompanion.insert(
            setId: setId,
            front: c.front,
            back: c.back,
            frontRich: Value(c.frontRich),
            backRich: Value(c.backRich),
            imagePath: Value(c.imagePath),
            audioPath: Value(c.audioPath),
            starred: Value(c.starred),
            vocabId: Value(c.vocabId),
            verified: Value(c.verified),
            position: Value(position++),
          ),
      ]);
    });
  }

  static CardDraft _validated(CardDraft d) {
    final front = d.front.trimmed();
    final back = d.back.trimmed();
    if (front.plainText.isEmpty) {
      throw const ValidationException('Die Vorderseite darf nicht leer sein');
    }
    if (back.plainText.isEmpty) {
      throw const ValidationException('Die Rückseite darf nicht leer sein');
    }
    return CardDraft(
      front: front,
      back: back,
      imagePath: d.imagePath,
      starred: d.starred,
    );
  }

  static String _requireName(String value, String field) {
    final t = value.trim();
    if (t.isEmpty) throw ValidationException('$field darf nicht leer sein');
    return t;
  }
}
