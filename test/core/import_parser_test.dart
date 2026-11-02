import 'package:barstardo_learning/core/import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseImport', () {
    test('Tab (aus Excel kopiert)', () {
      final r = parseImport(
        'la casa\tdas Haus\ncomer\tessen\n',
        ImportSeparator.tab,
      );
      expect(r.pairs, const [
        ImportedPair('la casa', 'das Haus'),
        ImportedPair('comer', 'essen'),
      ]);
      expect(r.invalidLines, isEmpty);
    });

    test('Komma: nur erstes Komma trennt, Rest gehört zur Rückseite', () {
      final r = parseImport('ev, Haus, Heim', ImportSeparator.comma);
      expect(r.pairs.single, const ImportedPair('ev', 'Haus, Heim'));
    });

    test('Semikolon mit Leerzeichen und Windows-Zeilenenden', () {
      final r = parseImport(
        ' su ;  Wasser \r\nekmek;Brot\r\n',
        ImportSeparator.semicolon,
      );
      expect(r.pairs, const [
        ImportedPair('su', 'Wasser'),
        ImportedPair('ekmek', 'Brot'),
      ]);
    });

    test(
      'Bindestrich: „ - “ wird bevorzugt, Wörter mit Bindestrich bleiben heil',
      () {
        final r = parseImport(
          'bien-estar - das Wohlbefinden\nperro-Hund',
          ImportSeparator.dash,
        );
        expect(r.pairs, const [
          ImportedPair('bien-estar', 'das Wohlbefinden'),
          ImportedPair('perro', 'Hund'),
        ]);
      },
    );

    test('Gedankenstrich aus Word zählt als Trenner', () {
      final r = parseImport('gato – Katze', ImportSeparator.dash);
      expect(r.pairs.single, const ImportedPair('gato', 'Katze'));
    });

    test('Anführungszeichen aus CSV werden entfernt', () {
      final r = parseImport(
        '"hola";"hallo, guten Tag"',
        ImportSeparator.semicolon,
      );
      expect(r.pairs.single, const ImportedPair('hola', 'hallo, guten Tag'));
    });

    test('ungültige Zeilen werden gemeldet, leere übersprungen', () {
      final r = parseImport(
        'uno\teins\n\nnur ein Wort\n\tleer vorne\ndos\t',
        ImportSeparator.tab,
      );
      expect(r.pairs.single, const ImportedPair('uno', 'eins'));
      expect(r.invalidLines, [3, 4, 5]);
    });
  });

  group('detectSeparator', () {
    test('erkennt Tab', () {
      expect(detectSeparator('a\tb\nc\td'), ImportSeparator.tab);
    });
    test('erkennt Semikolon vor Komma', () {
      expect(detectSeparator('a;b, c\nd;e'), ImportSeparator.semicolon);
    });
    test('erkennt Komma', () {
      expect(detectSeparator('a,b\nc,d'), ImportSeparator.comma);
    });
    test('erkennt Bindestrich', () {
      expect(detectSeparator('a - b\nc - d'), ImportSeparator.dash);
    });
  });
}
