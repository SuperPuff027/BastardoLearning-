import 'package:barstardo_learning/core/learning/grading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Verdict v(String given, String expected) =>
      gradeAnswer(given, expected).verdict;

  group('richtig', () {
    test('exakt', () => expect(v('la casa', 'la casa'), Verdict.correct));
    test(
      'Groß/Klein egal',
      () => expect(v('La CASA', 'la casa'), Verdict.correct),
    );
    test('Leerzeichen und Satzzeichen am Rand egal', () {
      expect(v('  ¡hola!  ', 'hola'), Verdict.correct);
      expect(v('buenos   días.', 'buenos días'), Verdict.correct);
    });
    test(
      'Artikel optional (es)',
      () => expect(v('casa', 'la casa'), Verdict.correct),
    );
    test(
      'Artikel optional (de)',
      () => expect(v('Haus', 'das Haus'), Verdict.correct),
    );
    test('Artikel in der Antwort, Ziel ohne Artikel', () {
      expect(v('das Haus', 'Haus'), Verdict.correct);
    });
    test('eine von mehreren Bedeutungen', () {
      expect(v('Heim', 'Haus, Heim'), Verdict.correct);
      expect(v('Heim', 'Haus; Heim'), Verdict.correct);
      expect(v('Heim', 'Haus / Heim'), Verdict.correct);
    });
    test('Klammerinhalt optional', () {
      expect(v('freuen', '(sich) freuen'), Verdict.correct);
      expect(v('sich freuen', '(sich) freuen'), Verdict.correct);
    });
    test(
      'türkisches großes İ',
      () => expect(v('İSTANBUL', 'istanbul'), Verdict.correct),
    );
    test(
      'kurzes Wort, das ein Artikel ist',
      () => expect(v('la', 'la'), Verdict.correct),
    );
  });

  group('fast richtig: Akzente', () {
    for (final (given, expected) in [
      ('cafe', 'café'),
      ('nino', 'niño'),
      ('aqui', 'aquí'),
      ('kus', 'kuş'),
      ('dag', 'dağ'),
      ('isik', 'ışık'),
      ('cocuk', 'çocuk'),
      ('gol', 'göl'),
      ('Fusse', 'Füße'),
    ]) {
      test('$given ≈ $expected', () {
        final r = gradeAnswer(given, expected);
        expect(r.verdict, Verdict.almostCorrect);
        expect(r.reason, AlmostReason.accents);
        expect(r.isAccepted, isTrue);
      });
    }
  });

  group('fast richtig: Tippfehler', () {
    test('ein Buchstabe falsch bei ≥ 5 Zeichen', () {
      final r = gradeAnswer('mesa grnde', 'mesa grande');
      expect(r.verdict, Verdict.almostCorrect);
      expect(r.reason, AlmostReason.typo);
    });
    test('vertauscht/fehlend', () {
      expect(v('ventna', 'ventana'), Verdict.almostCorrect);
      expect(v('Wassser', 'Wasser'), Verdict.almostCorrect);
    });
    test('Tippfehler plus fehlender Akzent', () {
      expect(v('cancin', 'canción'), Verdict.almostCorrect);
    });
  });

  group('falsch', () {
    test('kurze Wörter: kein Tippfehler-Bonus', () {
      expect(v('cosa', 'casa'), Verdict.wrong);
      expect(v('su', 'şu'), Verdict.almostCorrect); // nur Akzent
    });
    test('zwei Fehler', () => expect(v('ventnaa', 'ventana'), Verdict.wrong));
    test('leer', () => expect(v('   ', 'casa'), Verdict.wrong));
    test('ganz anderes Wort', () => expect(v('perro', 'gato'), Verdict.wrong));
  });

  test('falscher Artikel → fast richtig', () {
    final r = gradeAnswer('el casa', 'la casa');
    expect(r.verdict, Verdict.almostCorrect);
    expect(r.reason, AlmostReason.article);
  });

  group('Hilfsfunktionen', () {
    test('levenshtein', () {
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('abc', 'abc'), 0);
      expect(levenshtein('', 'ab'), 2);
      expect(levenshtein('abcdef', 'x', max: 1), 2);
    });
    test('expectedVariants', () {
      expect(
        expectedVariants('(sich) freuen, jubeln'),
        containsAll(['(sich) freuen', 'freuen', 'sich freuen', 'jubeln']),
      );
    });
  });
}
