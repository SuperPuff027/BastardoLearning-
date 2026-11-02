import 'package:barstardo_learning/core/scan/language_guess.dart';
import 'package:barstardo_learning/core/scan/lemmatizer.dart';
import 'package:barstardo_learning/core/scan/word_extractor.dart';
import 'package:barstardo_learning/data/vocab/vocab_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VocabRepository vocab;

  setUpAll(() => vocab = VocabRepository.open(VocabRepository.assetPath));
  tearDownAll(() => vocab.close());

  WordExtractor extractor({Map<String, String> myCards = const {}}) =>
      WordExtractor(
        lemmatizer: Lemmatizer(vocab.lookupForeign),
        lookupForeign: vocab.lookupForeign,
        lookupGerman: vocab.lookupGerman,
        myCards: myCards,
      );

  group('guessLanguage', () {
    test('typische Zeichen', () {
      expect(guessLanguage('¿Dónde está el niño?').best, 'es');
      expect(guessLanguage('Işık ağaçta').best, 'tr');
      expect(guessLanguage('Die Straße ist schön').best, 'de');
    });
    test('Funktionswörter', () {
      expect(guessLanguage('el perro y la casa').best, 'es');
      expect(guessLanguage('bir ev ve bir araba').best, 'tr');
      expect(guessLanguage('der Hund und die Katze').best, 'de');
    });
    test('ML-Kit-Hinweis zählt mit', () {
      expect(guessLanguage('casa', hint: {'es': 0.9}).best, 'es');
      expect(guessLanguage('123').best, isNull);
    });
  });

  group('Segmente', () {
    test('Vokabelliste mit Trennzeichen', () {
      final segs = extractor().segment([
        'la casa – das Haus',
        'el perro = der Hund',
        'comer: essen',
        'ev\tdas Haus',
      ]);
      expect(segs[0].map((s) => s.language), ['es', 'de']);
      expect(segs[1].map((s) => s.language), ['es', 'de']);
      expect(segs[2].map((s) => s.language), ['es', 'de']);
      expect(segs[3].map((s) => s.language), ['tr', 'de']);
    });
    test('Bindestrich im Wort trennt nicht', () {
      final segs = extractor().segment(['bien-estar']);
      expect(segs.single, hasLength(1));
    });
    test('vorherrschende Fremdsprache', () {
      final ex = extractor();
      expect(
        ex.dominantForeignLanguage(
          ex.segment(['Ayer comimos en casa.', 'Das war schön.']),
        ),
        'es',
      );
    });
  });

  group('Extraktion', () {
    test('Paare vom Blatt: Übersetzung vom Blatt, Grundform aus Datenbank', () {
      final ex = extractor();
      final words = ex.extract(
        ex.segment(['las casas – die Häuser', 'perro - Hund']),
        'es',
      );
      final casa = words.firstWhere((w) => w.front == 'la casa');
      expect(casa.back, 'die Häuser');
      expect(casa.source, TranslationSource.sheet);
      expect(casa.isNew, isFalse);
      final perro = words.firstWhere((w) => w.front == 'el perro');
      expect(perro.back, 'Hund');
    });

    test('Neue Wörter vom Blatt werden aufgenommen (nicht in der DB)', () {
      final ex = extractor();
      final words = ex.extract(ex.segment(['el xilófono – das Xylofon']), 'es');
      final w = words.single;
      expect(w.isNew, isTrue);
      expect(w.front, 'el xilófono');
      expect(w.back, 'das Xylofon');
      expect(w.selected, isTrue);
      expect(w.verified, isFalse);
    });

    test('Früher aufgenommene Wörter werden wiedererkannt', () {
      final ex = extractor(myCards: {'xilófono': 'das Xylofon'});
      final words = ex.extract(ex.segment(['Toco el xilófono.']), 'es');
      final w = words.firstWhere((w) => w.front == 'xilófono');
      expect(w.back, 'das Xylofon');
      expect(w.source, TranslationSource.myCards);
      expect(w.alreadyInCards, isTrue);
      expect(w.selected, isFalse); // gibt es schon
    });

    test(
      'Fließtext: Grundformen, Duplikate zusammengefasst, Rauschen abgewählt',
      () {
        final ex = extractor();
        final words = ex.extract(
          ex.segment(['Ayer comimos con Pedro en casa.', 'Comimos mucho.']),
          'es',
        );
        final fronts = words.map((w) => w.front).toList();
        expect(fronts, contains('comer'));
        expect(fronts, contains('la casa'));
        final comer = words.firstWhere((w) => w.front == 'comer');
        expect(comer.count, 2);
        expect(comer.back, 'essen');
        expect(comer.source, TranslationSource.vocabDb);
        final pedro = words.firstWhere((w) => w.surface == 'Pedro');
        expect(pedro.isNoise, isTrue);
        expect(pedro.selected, isFalse);
        final con = words.firstWhere((w) => w.surface == 'con');
        expect(con.selected, isFalse); // Füllwort
        expect(fronts, isNot(contains('el'))); // Artikel allein entfällt
      },
    );

    test('Gemischter Text: nur Wörter der Zielsprache', () {
      final ex = extractor();
      final segs = ex.segment([
        'Hausaufgabe für Montag',
        'Evlerimizde büyük bir bahçe var.',
      ]);
      final words = ex.extract(segs, 'tr');
      final fronts = words.map((w) => w.front).toSet();
      expect(fronts, containsAll(['ev', 'büyük', 'bahçe']));
      expect(fronts, isNot(contains('hausaufgabe')));
      expect(words.firstWhere((w) => w.front == 'ev').example, 'Evlerimizde');
    });

    test('Wort ohne Übersetzung: Quelle „fehlt“', () {
      final ex = extractor();
      final words = ex.extract(ex.segment(['Me gusta el xilófono.']), 'es');
      final x = words.firstWhere((w) => w.front == 'xilófono');
      expect(x.source, TranslationSource.none);
      expect(x.back, isEmpty);
    });
  });
}
