import 'dart:math';

import 'grading.dart';
import 'study_item.dart';

enum LearnQuestionType { multipleChoice, written }

class LearnQuestion {
  const LearnQuestion({
    required this.card,
    required this.type,
    required this.direction,
    this.choices = const [],
  });

  final StudyCard card;
  final LearnQuestionType type;
  final AskDirection direction;
  final List<String> choices;

  String get expected => card.answerFor(direction);
}

class LearnOutcome {
  const LearnOutcome(this.question, this.accepted, {this.grade});

  final LearnQuestion question;
  final bool accepted;
  final GradeResult? grade;
}

/// Adaptiver Lernmodus (Brief Nr. 12).
///
/// Jede Karte durchläuft zwei Stufen: erst Multiple Choice, dann Schreiben.
/// Eine falsche Antwort setzt die Karte auf Stufe 0 zurück und sie kommt nach
/// wenigen Fragen wieder. Es sind immer höchstens [poolSize] Karten „aktiv“;
/// Karten mit vielen bisherigen Fehlern kommen zuerst dran.
class LearnSession {
  LearnSession(
    List<StudyCard> cards, {
    required this.directions,
    Map<int, int> pastErrors = const {},
    this.poolSize = 7,
    this.retryGap = 3,
    Random? random,
  }) : _random = random ?? Random(),
       _all = List.unmodifiable(cards) {
    final ordered = [...cards]..shuffle(_random);
    // stabil nach Fehlern sortieren: viele Fehler zuerst
    ordered.sort(
      (a, b) => (pastErrors[b.id] ?? 0).compareTo(pastErrors[a.id] ?? 0),
    );
    _waiting.addAll(ordered);
    _fillPool();
    if (_queue.isNotEmpty) _current = _makeQuestion(_queue.first);
  }

  final DirectionPicker directions;
  final Random _random;
  final List<StudyCard> _all;
  final int poolSize;
  final int retryGap;

  final _waiting = <StudyCard>[];
  final _queue = <StudyCard>[];
  final _stage = <int, int>{};
  final _mistakes = <int, int>{};
  final _mastered = <StudyCard>[];
  LearnQuestion? _current;

  int get total => _all.length;
  int get masteredCount => _mastered.length;
  bool get isFinished => _current == null;
  LearnQuestion get current => _current!;

  /// Fortschritt 0..1, Teilpunkte für Stufe 1.
  double get progress {
    if (total == 0) return 1;
    var points = 0;
    for (final c in _all) {
      points += _stage[c.id] ?? 0;
    }
    return points / (2 * total);
  }

  int stageOf(StudyCard c) => _stage[c.id] ?? 0;
  int mistakesOf(StudyCard c) => _mistakes[c.id] ?? 0;

  /// Karten, die in dieser Sitzung mindestens einmal falsch waren.
  List<StudyCard> get troubleCards => [
    for (final c in _all)
      if ((_mistakes[c.id] ?? 0) > 0) c,
  ];

  bool get _mcPossible => _all.length >= 2;

  LearnQuestion _makeQuestion(StudyCard card) {
    final direction = directions.next();
    final stage = _stage[card.id] ?? 0;
    if (stage == 0 && _mcPossible) {
      return LearnQuestion(
        card: card,
        type: LearnQuestionType.multipleChoice,
        direction: direction,
        choices: choicesFor(card, direction, _all, _random),
      );
    }
    return LearnQuestion(
      card: card,
      type: LearnQuestionType.written,
      direction: direction,
    );
  }

  void _fillPool() {
    while (_queue.length < poolSize && _waiting.isNotEmpty) {
      _queue.add(_waiting.removeAt(0));
    }
  }

  LearnOutcome answerChoice(String choice) {
    final q = current;
    assert(q.type == LearnQuestionType.multipleChoice);
    return _record(q, choice.trim() == q.expected.trim());
  }

  LearnOutcome answerWritten(String text) {
    final q = current;
    final grade = gradeAnswer(text, q.expected);
    return _record(q, grade.isAccepted, grade: grade);
  }

  /// „Ich hatte recht“: die letzte geschriebene Antwort als richtig werten.
  void overrideLast(LearnOutcome outcome) {
    final card = outcome.question.card;
    // Rückgängig: Fehler zählen nicht, Stufe wie bei richtiger Antwort.
    _mistakes[card.id] = (_mistakes[card.id] ?? 1) - 1;
    final stage = (_lastStageBefore ?? 0) + (_mcPossible ? 1 : 2);
    _setStage(card, stage);
  }

  int? _lastStageBefore;

  LearnOutcome _record(LearnQuestion q, bool accepted, {GradeResult? grade}) {
    final card = q.card;
    _lastStageBefore = _stage[card.id] ?? 0;
    if (accepted) {
      // Ohne Multiple Choice (nur 1 Karte) reicht eine schriftliche Antwort.
      _setStage(card, _lastStageBefore! + (_mcPossible ? 1 : 2));
    } else {
      _mistakes[card.id] = (_mistakes[card.id] ?? 0) + 1;
      _setStage(card, 0);
    }
    return LearnOutcome(q, accepted, grade: grade);
  }

  void _setStage(StudyCard card, int stage) {
    _stage[card.id] = stage.clamp(0, 2);
  }

  /// Zur nächsten Frage weitergehen (nach Anzeige des Feedbacks).
  void next() {
    final card = _queue.removeAt(0);
    final stage = _stage[card.id] ?? 0;
    if (stage >= 2) {
      _mastered.add(card);
      _fillPool();
    } else if (stage == 0) {
      // Falsch: bald wieder
      _queue.insert(min(retryGap, _queue.length), card);
    } else {
      _queue.add(card);
    }
    // Nicht direkt dieselbe Karte zweimal hintereinander, wenn vermeidbar.
    _current = _queue.isEmpty ? null : _makeQuestion(_queue.first);
  }
}
