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

  group('parseVocabFile', () {
    test('Kopfzeile, Semikolon, Lektionen, Anführungszeichen', () {
      final f = parseVocabFile(
        '\uFEFFspanisch;deutsch;lektion\n'
        'el aeropuerto;Flughafen;Unidad 4\n'
        '¡qué fuerte!;"ein starkes Stück!; krass!";Unidad 8\n'
        'dar (y) un "abrazo";umarmen;Unidad 10\n'
        'kaputt\n'
        'abierto/a;offen;Unidad 9\n',
      );
      expect(f.rows, hasLength(4));
      expect(f.rows[1].back, 'ein starkes Stück!; krass!');
      expect(f.rows[2].front, 'dar (y) un "abrazo"');
      expect(f.groups, ['Unidad 4', 'Unidad 8', 'Unidad 9', 'Unidad 10']);
      expect(f.invalidLines, [5]);
    });

    test('Tab und Komma ohne Lektion', () {
      final tab = parseVocabFile('ev\tHaus\nsu\tWasser');
      expect(tab.rows.map((r) => r.back), ['Haus', 'Wasser']);
      expect(tab.groups, ['']);
      final comma = parseVocabFile('casa,Haus\nperro,Hund\n');
      expect(comma.rows.first.front, 'casa');
    });

    test('Windows-Zeilenenden, doppelte Anführungszeichen', () {
      final f = parseVocabFile('"a ""b""";c\r\nd;e\r\n');
      expect(f.rows.first.front, 'a "b"');
      expect(f.rows, hasLength(2));
    });

    test('naturalCompare', () {
      final l = ['Unidad 10', 'Unidad 2', 'Unidad 1']..sort(naturalCompare);
      expect(l, ['Unidad 1', 'Unidad 2', 'Unidad 10']);
    });
  });
}
