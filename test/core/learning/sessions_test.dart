import 'dart:math';

import 'package:barstardo_learning/core/learning/flashcard_session.dart';
import 'package:barstardo_learning/core/learning/grading.dart';
import 'package:barstardo_learning/core/learning/learn_session.dart';
import 'package:barstardo_learning/core/learning/study_item.dart';
import 'package:barstardo_learning/core/learning/test_generator.dart';
import 'package:barstardo_learning/core/learning/write_session.dart';
import 'package:barstardo_learning/features/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const cards = [
  StudyCard(id: 1, front: 'la casa', back: 'das Haus'),
  StudyCard(id: 2, front: 'el perro', back: 'der Hund'),
  StudyCard(id: 3, front: 'el gato', back: 'die Katze'),
  StudyCard(id: 4, front: 'comer', back: 'essen'),
  StudyCard(id: 5, front: 'beber', back: 'trinken'),
];

DirectionPicker f2d() => DirectionPicker(QuizDirection.foreignToGerman);

void main() {
  group('DirectionPicker', () {
    test('feste Richtungen', () {
      expect(
        DirectionPicker(QuizDirection.foreignToGerman).next(),
        AskDirection.foreignToGerman,
      );
      expect(
        DirectionPicker(QuizDirection.germanToForeign).next(),
        AskDirection.germanToForeign,
      );
    });
    test('gemischt liefert beide Richtungen', () {
      final p = DirectionPicker(QuizDirection.mixed, Random(1));
      final seen = {for (var i = 0; i < 50; i++) p.next()};
      expect(seen, AskDirection.values.toSet());
    });
    test('Karte liefert Frage/Antwort je Richtung', () {
      const c = StudyCard(id: 1, front: 'sí', back: 'ja');
      expect(c.promptFor(AskDirection.foreignToGerman), 'sí');
      expect(c.answerFor(AskDirection.foreignToGerman), 'ja');
      expect(c.promptFor(AskDirection.germanToForeign), 'ja');
      expect(c.answerFor(AskDirection.germanToForeign), 'sí');
    });
  });

  test('choicesFor: richtige Antwort + eindeutige Ablenker', () {
    const dup = [
      ...cards,
      StudyCard(id: 6, front: 'el hogar', back: 'das Haus'), // gleiche Antwort
    ];
    final choices = choicesFor(
      cards[0],
      AskDirection.foreignToGerman,
      dup,
      Random(3),
    );
    expect(choices, hasLength(4));
    expect(choices, contains('das Haus'));
    expect(choices.where((c) => c == 'das Haus'), hasLength(1));
    expect(choices.toSet(), hasLength(4));
  });

  group('FlashcardSession', () {
    test('gewusst/nicht gewusst, Wiederholung der nicht gewussten', () {
      final s = FlashcardSession(cards.take(3).toList(), directions: f2d());
      expect(s.current.id, 1);
      s.answer(knewIt: true);
      s.answer(knewIt: false);
      s.answer(knewIt: false);
      expect(s.isFinished, isTrue);
      expect(s.known.map((c) => c.id), [1]);
      expect(s.unknown.map((c) => c.id), [2, 3]);

      final retry = s.retryUnknown();
      expect(retry.total, 2);
    });
    test('undo', () {
      final s = FlashcardSession(cards.take(2).toList(), directions: f2d());
      s.answer(knewIt: false);
      expect(s.undo(), isTrue);
      expect(s.unknown, isEmpty);
      expect(s.current.id, 1);
      expect(s.undo(), isFalse);
    });
    test('mischen ändert die Reihenfolge, nicht den Inhalt', () {
      final s = FlashcardSession(
        cards,
        directions: f2d(),
        shuffle: true,
        random: Random(7),
      );
      final ids = <int>[];
      while (!s.isFinished) {
        ids.add(s.current.id);
        s.answer(knewIt: true);
      }
      expect(ids.toSet(), {1, 2, 3, 4, 5});
    });
  });

  group('WriteSession', () {
    test('bewertet, überstimmen, falsche wiederholen', () {
      final s = WriteSession(
        cards.take(3).toList(),
        directions: f2d(),
        shuffle: false,
      );
      final a1 = s.submit('Haus');
      expect(a1.result.verdict, Verdict.correct);
      s.next();
      final a2 = s.submit('Hunt');
      expect(a2.accepted, isFalse); // „Hund“ hat nur 4 Zeichen
      s.overrideCorrect();
      expect(a2.accepted, isTrue);
      s.next();
      s.submit('Maus');
      s.next();
      expect(s.isFinished, isTrue);
      expect(s.correctCount, 2);
      expect(s.wrongCards.map((c) => c.id), [3]);
      expect(s.retryWrong().total, 1);
    });
  });

  group('LearnSession', () {
    test(
      'jede Karte: erst Multiple Choice, dann Schreiben, dann gemeistert',
      () {
        final s = LearnSession(
          cards.take(2).toList(),
          directions: f2d(),
          random: Random(1),
        );
        final seenTypes = <int, List<LearnQuestionType>>{};
        var guard = 0;
        while (!s.isFinished && guard++ < 20) {
          final q = s.current;
          seenTypes.putIfAbsent(q.card.id, () => []).add(q.type);
          if (q.type == LearnQuestionType.multipleChoice) {
            expect(q.choices, contains(q.expected));
            s.answerChoice(q.expected);
          } else {
            s.answerWritten(q.expected);
          }
          s.next();
        }
        expect(s.isFinished, isTrue);
        expect(s.masteredCount, 2);
        expect(s.progress, 1.0);
        for (final types in seenTypes.values) {
          expect(types, [
            LearnQuestionType.multipleChoice,
            LearnQuestionType.written,
          ]);
        }
      },
    );

    test('falsche Antwort setzt zurück und die Karte kommt bald wieder', () {
      final s = LearnSession(
        cards,
        directions: f2d(),
        random: Random(2),
        retryGap: 2,
      );
      final first = s.current.card;
      s.answerChoice('völlig falsch');
      expect(s.stageOf(first), 0);
      expect(s.mistakesOf(first), 1);
      s.next();
      s.answerChoice(s.current.expected);
      s.next();
      s.answerChoice(s.current.expected);
      s.next();
      expect(s.current.card, first); // nach 2 anderen Fragen wieder dran
      expect(s.troubleCards, [first]);
    });

    test('Karten mit vielen Fehlern zuerst', () {
      final s = LearnSession(
        cards,
        directions: f2d(),
        pastErrors: {4: 5, 2: 1},
        random: Random(9),
      );
      expect(s.current.card.id, 4);
    });

    test('Pool begrenzt die aktiven Karten', () {
      final s = LearnSession(
        cards,
        directions: f2d(),
        poolSize: 2,
        random: Random(4),
      );
      final ids = <int>{};
      for (var i = 0; i < 4; i++) {
        ids.add(s.current.card.id);
        if (s.current.type == LearnQuestionType.multipleChoice) {
          s.answerChoice(s.current.expected);
        } else {
          s.answerWritten(s.current.expected);
        }
        s.next();
      }
      expect(ids, hasLength(2));
    });

    test('mit nur einer Karte: direkt Schreiben', () {
      final s = LearnSession([cards.first], directions: f2d());
      expect(s.current.type, LearnQuestionType.written);
      s.answerWritten('Haus');
      s.next();
      expect(s.isFinished, isTrue);
    });

    test('„Ich hatte recht“ korrigiert Fehler und Stufe', () {
      final s = LearnSession([cards.first], directions: f2d());
      final o = s.answerWritten('Hauss Haus');
      expect(o.accepted, isFalse);
      s.overrideLast(o);
      expect(s.mistakesOf(cards.first), 0);
      expect(s.stageOf(cards.first), 2);
      s.next();
      expect(s.isFinished, isTrue);
    });
  });

  group('TestGenerator', () {
    TestGenerator gen([int seed = 1]) =>
        TestGenerator(directions: f2d(), random: Random(seed));

    test('Anzahl und Typen werden eingehalten', () {
      final qs = gen().generate(
        cards,
        const TestConfig(
          questionCount: 4,
          types: {TestQuestionType.multipleChoice, TestQuestionType.written},
        ),
      );
      expect(qs, hasLength(4));
      expect(qs.whereType<MultipleChoiceQuestion>(), hasLength(2));
      expect(qs.whereType<WrittenQuestion>(), hasLength(2));
    });

    test('Zuordnen bündelt Karten; Punkte pro Paar', () {
      final qs = gen().generate(
        cards,
        const TestConfig(questionCount: 5, types: {TestQuestionType.matching}),
      );
      expect(qs, hasLength(1));
      final m = qs.single as MatchingQuestion;
      expect(m.maxPoints, 5);
      for (final c in m.cards) {
        m.selections[c.id] = c.back;
      }
      expect(m.points, 5);
      expect(m.isAnswered, isTrue);
    });

    test('Wahr/Falsch und Bewertung', () {
      final qs = gen(5).generate(
        cards,
        const TestConfig(questionCount: 5, types: {TestQuestionType.trueFalse}),
      );
      expect(qs, hasLength(5));
      for (final q in qs.cast<TrueFalseQuestion>()) {
        q.selected = q.isTrue;
      }
      final score = TestScore.of(qs);
      expect(score.points, 5);
      expect(score.percent, 100);
      expect(qs.cast<TrueFalseQuestion>().any((q) => !q.isTrue), isTrue);
    });

    test('Freitext nutzt die smarte Bewertung', () {
      final qs = gen().generate([
        cards.first,
      ], const TestConfig(questionCount: 1, types: {TestQuestionType.written}));
      final w = qs.single as WrittenQuestion;
      w.text = 'haus';
      expect(w.points, 1);
      w.text = 'Maus';
      expect(w.points, 0);
      w.overridden = true;
      expect(w.points, 1);
    });

    test('nur eine Karte: Multiple Choice fällt auf Freitext zurück', () {
      final qs = gen().generate(
        [cards.first],
        const TestConfig(
          questionCount: 1,
          types: {TestQuestionType.multipleChoice},
        ),
      );
      expect(qs.single, isA<WrittenQuestion>());
    });

    test('Multiple Choice: Score', () {
      final qs = gen().generate(
        cards,
        const TestConfig(
          questionCount: 3,
          types: {TestQuestionType.multipleChoice},
        ),
      );
      final mc = qs.cast<MultipleChoiceQuestion>();
      mc.elementAt(0).selected = mc.elementAt(0).expected;
      mc.elementAt(1).selected = 'falsch';
      expect(TestScore.of(qs).points, 1);
      expect(TestScore.of(qs).maxPoints, 3);
      expect(mc.elementAt(2).isAnswered, isFalse);
    });
  });
}
