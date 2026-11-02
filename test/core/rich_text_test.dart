import 'package:barstardo_learning/core/rich_text.dart';
import 'package:barstardo_learning/core/rich_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const bold = RichStyle(bold: true);

void main() {
  group('RichDocument', () {
    test('unformatierter Text wird nicht als JSON gespeichert', () {
      expect(RichDocument.plain('hola').encode(), isNull);
    });

    test('Roundtrip encode/decode', () {
      final doc = RichDocument(const [
        RichSpan('la '),
        RichSpan('casa', RichStyle(bold: true, color: RichColor.red)),
        RichSpan(' grande', RichStyle(italic: true)),
      ]);
      final json = doc.encode();
      expect(json, isNotNull);
      expect(RichDocument.decode('la casa grande', json), doc);
    });

    test('benachbarte gleiche Stile werden zusammengefasst', () {
      final doc = RichDocument(const [
        RichSpan('a', bold),
        RichSpan('b', bold),
        RichSpan(''),
      ]);
      expect(doc.spans, const [RichSpan('ab', bold)]);
    });

    test('kaputtes oder veraltetes JSON fällt auf Klartext zurück', () {
      expect(
        RichDocument.decode('hola', '{kaputt'),
        RichDocument.plain('hola'),
      );
      final other = RichDocument(const [RichSpan('adiós', bold)]).encode();
      expect(RichDocument.decode('hola', other), RichDocument.plain('hola'));
    });

    test('trimmed behält Formatierung', () {
      final doc = RichDocument(const [
        RichSpan('  '),
        RichSpan('sí', bold),
        RichSpan(' '),
      ]);
      expect(doc.trimmed(), RichDocument(const [RichSpan('sí', bold)]));
    });
  });

  group('RichTextController', () {
    void type(RichTextController c, String newText, int cursor) {
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor),
      );
    }

    test('Auswahl fett machen und wieder entfernen', () {
      final c = RichTextController(document: RichDocument.plain('la casa'));
      c.selection = const TextSelection(baseOffset: 3, extentOffset: 7);
      c.toggleBold();
      expect(c.document.spans, const [RichSpan('la '), RichSpan('casa', bold)]);
      expect(c.currentStyle.bold, isTrue);
      c.toggleBold();
      expect(c.document.hasFormatting, isFalse);
    });

    test('getippte Zeichen übernehmen den Stil davor', () {
      final c = RichTextController(
        document: RichDocument(const [RichSpan('ab', bold)]),
      );
      c.selection = const TextSelection.collapsed(offset: 2);
      type(c, 'abc', 3);
      expect(c.document.spans, const [RichSpan('abc', bold)]);
    });

    test('Formatierung bei leerer Auswahl gilt für die nächsten Zeichen', () {
      final c = RichTextController(document: RichDocument.plain('el '));
      c.selection = const TextSelection.collapsed(offset: 3);
      c.toggleItalic();
      type(c, 'el g', 4);
      type(c, 'el ga', 5);
      expect(c.document.spans, const [
        RichSpan('el '),
        RichSpan('ga', RichStyle(italic: true)),
      ]);
    });

    test('Löschen in der Mitte entfernt die passenden Stile', () {
      final c = RichTextController(
        document: RichDocument(const [
          RichSpan('ab'),
          RichSpan('cd', bold),
          RichSpan('ef'),
        ]),
      );
      type(c, 'abdef', 2); // „c“ gelöscht
      expect(c.document.spans, const [
        RichSpan('ab'),
        RichSpan('d', bold),
        RichSpan('ef'),
      ]);
    });

    test('Farbe setzen und Formatierung entfernen', () {
      final c = RichTextController(document: RichDocument.plain('rojo'));
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      c.setColor(RichColor.red);
      expect(c.document.spans.single.style.color, RichColor.red);
      c.clearFormatting();
      expect(c.document.hasFormatting, isFalse);
    });

    test('Ersetzen der ganzen Auswahl', () {
      final c = RichTextController(
        document: RichDocument(const [RichSpan('alt', bold)]),
      );
      type(c, 'neu', 3);
      expect(c.document.spans, const [RichSpan('neu', bold)]);
    });
  });
}
