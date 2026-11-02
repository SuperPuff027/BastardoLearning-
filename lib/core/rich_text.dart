import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Farben für Rich Text. Gespeichert wird nur der Schlüssel; die konkrete
/// Farbe wird je nach Hell/Dunkel-Modus gewählt.
enum RichColor { red, orange, green, blue, purple }

/// Formatierung eines Textabschnitts.
@immutable
class RichStyle {
  const RichStyle({this.bold = false, this.italic = false, this.color});

  static const plain = RichStyle();

  final bool bold;
  final bool italic;
  final RichColor? color;

  bool get isPlain => !bold && !italic && color == null;

  RichStyle copyWith({
    bool? bold,
    bool? italic,
    RichColor? Function()? color,
  }) => RichStyle(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    color: color != null ? color() : this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is RichStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.color == color;

  @override
  int get hashCode => Object.hash(bold, italic, color);

  @override
  String toString() =>
      'RichStyle(${[if (bold) 'b', if (italic) 'i', if (color != null) color!.name].join(',')})';
}

@immutable
class RichSpan {
  const RichSpan(this.text, [this.style = RichStyle.plain]);

  final String text;
  final RichStyle style;

  @override
  bool operator ==(Object other) =>
      other is RichSpan && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => 'RichSpan("$text", $style)';
}

/// Formatierter Text einer Kartenseite.
///
/// In der Datenbank steht immer der Klartext (für Suche und Bewertung) und
/// nur bei vorhandener Formatierung zusätzlich das JSON aus [encode].
@immutable
class RichDocument {
  RichDocument(List<RichSpan> spans)
    : spans = List.unmodifiable(_normalize(spans));

  factory RichDocument.plain(String text) => RichDocument([RichSpan(text)]);

  /// Baut ein Dokument aus einem Stil pro UTF-16-Zeichen.
  factory RichDocument.fromStyles(String text, List<RichStyle> styles) {
    assert(text.length == styles.length);
    final spans = <RichSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || styles[i] != styles[start]) {
        spans.add(RichSpan(text.substring(start, i), styles[start]));
        start = i;
      }
    }
    return RichDocument(spans);
  }

  /// Liest gespeichertes JSON; fällt bei Fehlern oder abweichendem Klartext
  /// auf [plainText] zurück.
  factory RichDocument.decode(String plainText, String? json) {
    if (json == null || json.isEmpty) return RichDocument.plain(plainText);
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final spans = [
        for (final s in data['spans'] as List)
          RichSpan(
            (s as Map<String, dynamic>)['t'] as String,
            RichStyle(
              bold: s['b'] == true,
              italic: s['i'] == true,
              color: _colorByName(s['c'] as String?),
            ),
          ),
      ];
      final doc = RichDocument(spans);
      return doc.plainText == plainText ? doc : RichDocument.plain(plainText);
    } catch (_) {
      return RichDocument.plain(plainText);
    }
  }

  final List<RichSpan> spans;

  String get plainText => spans.map((s) => s.text).join();

  bool get hasFormatting => spans.any((s) => !s.style.isPlain);

  /// Ein Stil pro UTF-16-Zeichen.
  List<RichStyle> get styles => [
    for (final s in spans)
      for (var i = 0; i < s.text.length; i++) s.style,
  ];

  /// JSON für die Datenbank, oder `null`, wenn der Text unformatiert ist.
  String? encode() {
    if (!hasFormatting) return null;
    return jsonEncode({
      'v': 1,
      'spans': [
        for (final s in spans)
          {
            't': s.text,
            if (s.style.bold) 'b': true,
            if (s.style.italic) 'i': true,
            if (s.style.color != null) 'c': s.style.color!.name,
          },
      ],
    });
  }

  /// Entfernt führende und abschließende Leerzeichen, Formatierung bleibt.
  RichDocument trimmed() {
    final text = plainText;
    final start = text.length - text.trimLeft().length;
    final end = text.trimRight().length;
    if (start >= end) return RichDocument.plain('');
    final s = styles;
    return RichDocument.fromStyles(
      text.substring(start, end),
      s.sublist(start, end),
    );
  }

  static RichColor? _colorByName(String? name) {
    if (name == null) return null;
    for (final c in RichColor.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  static List<RichSpan> _normalize(List<RichSpan> spans) {
    final out = <RichSpan>[];
    for (final s in spans) {
      if (s.text.isEmpty) continue;
      if (out.isNotEmpty && out.last.style == s.style) {
        out[out.length - 1] = RichSpan(out.last.text + s.text, s.style);
      } else {
        out.add(s);
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is RichDocument && listEquals(other.spans, spans);

  @override
  int get hashCode => Object.hashAll(spans);

  @override
  String toString() => 'RichDocument($spans)';
}
