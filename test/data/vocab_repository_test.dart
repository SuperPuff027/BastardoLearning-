import 'package:barstardo_learning/data/vocab/vocab_entry.dart';
import 'package:barstardo_learning/data/vocab/vocab_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testet gegen die echte, mitgelieferte Datenbank.
void main() {
  late VocabRepository vocab;

  setUpAll(() => vocab = VocabRepository.open(VocabRepository.assetPath));
  tearDownAll(() => vocab.close());

  test('Datenbank enthält je ~1.000 Einträge und Lizenzhinweis', () {
    expect(vocab.count('es'), greaterThanOrEqualTo(1000));
    expect(vocab.count('tr'), greaterThanOrEqualTo(1000));
    expect(vocab.attribution, contains('CC BY-SA 4.0'));
  });

  group('lookupForeign (Grundform aus gebeugter Form)', () {
    test('spanisches Verb', () {
      expect(vocab.lookupForeign('es', 'comimos').first.lemma, 'comer');
    });
    test('spanisches Nomen mit Artikel und Plural', () {
      final casa = vocab.lookupForeign('es', 'La Casa').first;
      expect(casa.lemma, 'casa');
      expect(casa.article, 'la');
      expect(casa.cardFront, 'la casa');
      expect(
        vocab.lookupForeign('es', 'casas').map((e) => e.lemma),
        contains('casa'),
      );
    });
    test('ohne Akzente', () {
      expect(vocab.lookupForeign('es', 'adios').first.lemma, 'adiós');
      expect(vocab.lookupForeign('tr', 'cocuk').first.lemma, 'çocuk');
    });
    test('türkische Formen', () {
      expect(vocab.lookupForeign('tr', 'evde').first.lemma, 'ev');
      expect(vocab.lookupForeign('tr', 'kitabı').first.lemma, 'kitap');
      expect(vocab.lookupForeign('tr', 'İSTANBUL'), isEmpty);
    });
    test('Sprache wird beachtet', () {
      expect(vocab.lookupForeign('tr', 'casa'), isEmpty);
    });
  });

  test('lookupGerman mit und ohne Artikel', () {
    expect(vocab.lookupGerman('es', 'das Haus').first.lemma, 'casa');
    expect(vocab.lookupGerman('tr', 'Haus').first.lemma, 'ev');
  });

  test('Vorschläge beim Tippen', () {
    final s = vocab.suggestForeign('es', 'cas');
    expect(s.map((e) => e.lemma), contains('casa'));
    expect(vocab.suggestForeign('es', 'c'), isEmpty); // zu kurz
    expect(
      vocab.suggestGerman('tr', 'Wass').map((e) => e.lemma),
      contains('su'),
    );
  });

  test('vorgefertigte Sets: Gruppen und Einträge', () {
    final groups = vocab.presetGroups('es');
    final a1 = groups.firstWhere((g) => g.cefrLevel == 'A1' && g.tag == null);
    expect(a1.label, 'Grundwortschatz A1');
    final food = groups.firstWhere(
      (g) => g.cefrLevel == 'A1' && g.tag == 'essen',
    );
    expect(food.label, 'A1 – Essen & Trinken');
    final entries = vocab.entriesFor(food);
    expect(entries, hasLength(food.count));
    expect(entries.every((e) => e.tags.contains('essen')), isTrue);
    expect(entries.every((e) => e.cefrLevel == 'A1'), isTrue);
  });

  test('Kartentext: mf-Nomen und Rückseite', () {
    final e = vocab.lookupForeign('es', 'estudiante').first;
    expect(e.cardFront, 'estudiante (m./f.)');
    expect(e.cardBack.split(', ').length, lessThanOrEqualTo(3));
    expect(
      const VocabEntry(
        id: 1,
        language: 'tr',
        lemma: 'ev',
        pos: 'noun',
        cefrLevel: 'A1',
        translations: ['das Haus', 'das Zuhause'],
      ).cardBack,
      'das Haus, das Zuhause',
    );
  });

  test('normalizeKey', () {
    expect(normalizeKey('  ¿Qué tal?  '), 'qué tal');
    expect(normalizeKey('(sich) freuen'), 'freuen');
    expect(stripGermanArticle('das haus'), 'haus');
  });
}
