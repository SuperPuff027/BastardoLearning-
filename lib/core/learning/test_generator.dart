import 'dart:math';

import 'grading.dart';
import 'study_item.dart';

enum TestQuestionType {
  multipleChoice('Multiple Choice'),
  trueFalse('Wahr/Falsch'),
  written('Freitext'),
  matching('Zuordnen');

  const TestQuestionType(this.label);
  final String label;
}

class TestConfig {
  const TestConfig({required this.questionCount, required this.types});

  /// Anzahl der abgefragten Karten.
  final int questionCount;
  final Set<TestQuestionType> types;
}

sealed class TestQuestion {
  TestQuestion(this.direction);

  final AskDirection direction;

  /// Punkte, die es für diese Frage gibt.
  int get maxPoints;

  /// Erreichte Punkte für die aktuelle Antwort.
  int get points;

  bool get isAnswered;
}

class MultipleChoiceQuestion extends TestQuestion {
  MultipleChoiceQuestion(this.card, super.direction, this.choices);

  final StudyCard card;
  final List<String> choices;
  String? selected;

  String get expected => card.answerFor(direction);

  @override
  int get maxPoints => 1;
  @override
  int get points => selected != null && selected == expected ? 1 : 0;
  @override
  bool get isAnswered => selected != null;
}

class TrueFalseQuestion extends TestQuestion {
  TrueFalseQuestion(this.card, super.direction, this.shownAnswer);

  final StudyCard card;

  /// Angezeigte Antwort; stimmt, wenn sie zur Karte gehört.
  final String shownAnswer;
  bool? selected;

  bool get isTrue => shownAnswer == card.answerFor(direction);

  @override
  int get maxPoints => 1;
  @override
  int get points => selected != null && selected == isTrue ? 1 : 0;
  @override
  bool get isAnswered => selected != null;
}

class WrittenQuestion extends TestQuestion {
  WrittenQuestion(this.card, super.direction);

  final StudyCard card;
  String text = '';
  bool overridden = false;

  String get expected => card.answerFor(direction);
  GradeResult get grade => gradeAnswer(text, expected);

  @override
  int get maxPoints => 1;
  @override
  int get points => overridden || grade.isAccepted ? 1 : 0;
  @override
  bool get isAnswered => text.trim().isNotEmpty;
}

class MatchingQuestion extends TestQuestion {
  MatchingQuestion(this.cards, super.direction, this.answerOptions);

  final List<StudyCard> cards;

  /// Antworten in gemischter Reihenfolge.
  final List<String> answerOptions;

  /// Karten-ID → gewählte Antwort.
  final selections = <int, String>{};

  @override
  int get maxPoints => cards.length;
  @override
  int get points =>
      cards.where((c) => selections[c.id] == c.answerFor(direction)).length;
  @override
  bool get isAnswered => selections.length == cards.length;
}

/// Erstellt einen Test (Brief Nr. 15).
class TestGenerator {
  TestGenerator({required this.directions, Random? random})
    : _random = random ?? Random();

  final DirectionPicker directions;
  final Random _random;

  List<TestQuestion> generate(List<StudyCard> cards, TestConfig config) {
    if (cards.isEmpty || config.types.isEmpty) return const [];
    final selected = ([...cards]..shuffle(_random))
        .take(config.questionCount.clamp(1, cards.length))
        .toList();

    var types = config.types.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    // Typen, die mehrere Karten brauchen, nur bei genug Karten.
    if (cards.length < 2) {
      types = types.where((t) => t == TestQuestionType.written).toList();
      if (types.isEmpty) types = [TestQuestionType.written];
    }

    // Karten gleichmäßig auf die Typen verteilen.
    final buckets = {for (final t in types) t: <StudyCard>[]};
    for (var i = 0; i < selected.length; i++) {
      buckets[types[i % types.length]]!.add(selected[i]);
    }
    // Zuordnen braucht mindestens 2 Karten pro Block.
    final matching = buckets[TestQuestionType.matching];
    if (matching != null && matching.length == 1) {
      final fallback = types.firstWhere(
        (t) => t != TestQuestionType.matching,
        orElse: () => TestQuestionType.written,
      );
      buckets.putIfAbsent(fallback, () => []).addAll(matching);
      matching.clear();
    }

    final questions = <TestQuestion>[];
    for (final entry in buckets.entries) {
      switch (entry.key) {
        case TestQuestionType.multipleChoice:
          for (final c in entry.value) {
            final d = directions.next();
            questions.add(
              MultipleChoiceQuestion(c, d, choicesFor(c, d, cards, _random)),
            );
          }
        case TestQuestionType.trueFalse:
          for (final c in entry.value) {
            final d = directions.next();
            final showTrue = _random.nextBool();
            var shown = c.answerFor(d);
            if (!showTrue) {
              final others = cards
                  .where(
                    (o) => o.id != c.id && o.answerFor(d) != c.answerFor(d),
                  )
                  .toList();
              if (others.isNotEmpty) {
                shown = others[_random.nextInt(others.length)].answerFor(d);
              }
            }
            questions.add(TrueFalseQuestion(c, d, shown));
          }
        case TestQuestionType.written:
          for (final c in entry.value) {
            questions.add(WrittenQuestion(c, directions.next()));
          }
        case TestQuestionType.matching:
          final group = entry.value;
          for (var i = 0; i < group.length; i += 5) {
            var block = group.sublist(i, min(i + 5, group.length));
            if (block.length == 1 && questions.isNotEmpty) {
              // Rest von 1 an den vorherigen Block hängen
              final prev = questions.last;
              if (prev is MatchingQuestion) {
                block = [...prev.cards, ...block];
                questions.removeLast();
              }
            }
            final d = directions.next();
            final answers = [for (final c in block) c.answerFor(d)]
              ..shuffle(_random);
            questions.add(MatchingQuestion(block, d, answers));
          }
      }
    }
    return questions;
  }
}

class TestScore {
  const TestScore(this.points, this.maxPoints);

  factory TestScore.of(List<TestQuestion> questions) => TestScore(
    questions.fold(0, (s, q) => s + q.points),
    questions.fold(0, (s, q) => s + q.maxPoints),
  );

  final int points;
  final int maxPoints;

  int get percent => maxPoints == 0 ? 0 : (points * 100 / maxPoints).round();
}
