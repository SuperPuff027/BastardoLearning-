import 'dart:math';

import 'grading.dart';
import 'study_item.dart';

class WriteAnswer {
  WriteAnswer(this.card, this.direction, this.given, this.result);

  final StudyCard card;
  final AskDirection direction;
  final String given;
  GradeResult result;

  /// „Ich hatte recht“ wurde gedrückt.
  bool overridden = false;

  bool get accepted => overridden || result.isAccepted;
}

/// Schreiben-Modus: Antwort eintippen, smarte Bewertung.
class WriteSession {
  WriteSession(
    List<StudyCard> cards, {
    required this.directions,
    bool shuffle = true,
    Random? random,
  }) : _random = random ?? Random() {
    _queue = [...cards];
    if (shuffle) _queue.shuffle(_random);
    if (_queue.isNotEmpty) _direction = directions.next();
  }

  final DirectionPicker directions;
  final Random _random;
  late List<StudyCard> _queue;
  int _index = 0;
  AskDirection _direction = AskDirection.foreignToGerman;

  final answers = <WriteAnswer>[];

  /// Antwort zur aktuellen Karte, sobald sie bewertet wurde.
  WriteAnswer? pending;

  int get total => _queue.length;
  int get position => _index;
  bool get isFinished => _index >= _queue.length;
  StudyCard get current => _queue[_index];
  AskDirection get direction => _direction;

  int get correctCount => answers.where((a) => a.accepted).length;
  List<StudyCard> get wrongCards => [
    for (final a in answers)
      if (!a.accepted) a.card,
  ];

  WriteAnswer submit(String given) {
    assert(pending == null);
    final a = WriteAnswer(
      current,
      _direction,
      given,
      gradeAnswer(given, current.answerFor(_direction)),
    );
    pending = a;
    answers.add(a);
    return a;
  }

  /// Bewertung durch den Nutzer überstimmen.
  void overrideCorrect() => pending?.overridden = true;

  void next() {
    pending = null;
    _index++;
    if (!isFinished) _direction = directions.next();
  }

  WriteSession retryWrong() =>
      WriteSession(wrongCards, directions: directions, random: _random);
}
