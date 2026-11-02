import 'dart:math';

import 'study_item.dart';

/// Karteikarten-Modus: umdrehen, wischen (gewusst / nicht gewusst).
class FlashcardSession {
  FlashcardSession(
    List<StudyCard> cards, {
    required this.directions,
    bool shuffle = false,
    Random? random,
  }) : _random = random ?? Random() {
    _queue = [...cards];
    if (shuffle) _queue.shuffle(_random);
    _currentDirection = directions.next();
  }

  final DirectionPicker directions;
  final Random _random;
  late List<StudyCard> _queue;
  int _index = 0;
  late AskDirection _currentDirection;

  final known = <StudyCard>[];
  final unknown = <StudyCard>[];

  int get total => _queue.length;
  int get position => _index;
  bool get isFinished => _index >= _queue.length;
  StudyCard get current => _queue[_index];
  AskDirection get direction => _currentDirection;

  void answer({required bool knewIt}) {
    (knewIt ? known : unknown).add(current);
    _index++;
    if (!isFinished) _currentDirection = directions.next();
  }

  /// Letzte Antwort zurücknehmen.
  bool undo() {
    if (_index == 0) return false;
    _index--;
    final card = _queue[_index];
    known.remove(card);
    unknown.remove(card);
    return true;
  }

  /// Neue Runde nur mit den nicht gewussten Karten.
  FlashcardSession retryUnknown({bool shuffle = false}) => FlashcardSession(
    unknown,
    directions: directions,
    shuffle: shuffle,
    random: _random,
  );
}
