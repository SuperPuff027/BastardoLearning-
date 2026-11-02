import 'package:flutter/material.dart';

import 'rich_text.dart';
import 'rich_text_style.dart';

/// TextEditingController mit Formatierung pro Zeichen (fett, kursiv, Farbe).
///
/// Bei jeder Textänderung wird per Präfix/Suffix-Vergleich ermittelt, welcher
/// Bereich ersetzt wurde; neue Zeichen übernehmen den Stil des Zeichens davor
/// bzw. den zuvor gewählten Tipp-Stil.
class RichTextController extends TextEditingController {
  RichTextController({RichDocument? document})
    : _styles = document?.styles ?? <RichStyle>[],
      super(text: document?.plainText ?? '');

  List<RichStyle> _styles;

  /// Stil für die nächsten getippten Zeichen, wenn bei leerer Auswahl
  /// eine Formatierung umgeschaltet wurde.
  RichStyle? _pendingStyle;
  int? _pendingOffset;

  RichDocument get document => RichDocument.fromStyles(text, _styles);

  set document(RichDocument doc) {
    _pendingStyle = null;
    _styles = doc.styles;
    super.value = TextEditingValue(
      text: doc.plainText,
      selection: TextSelection.collapsed(offset: doc.plainText.length),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    if (oldText != newText) {
      final maxPrefix = oldText.length < newText.length
          ? oldText.length
          : newText.length;
      var prefix = 0;
      while (prefix < maxPrefix &&
          oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
        prefix++;
      }
      var suffix = 0;
      while (suffix < maxPrefix - prefix &&
          oldText.codeUnitAt(oldText.length - 1 - suffix) ==
              newText.codeUnitAt(newText.length - 1 - suffix)) {
        suffix++;
      }
      final insertedLength = newText.length - prefix - suffix;
      final RichStyle insertStyle;
      if (_pendingStyle != null && _pendingOffset == prefix) {
        insertStyle = _pendingStyle!;
      } else if (prefix > 0) {
        insertStyle = _styles[prefix - 1];
      } else if (_styles.isNotEmpty && oldText.length - suffix > 0) {
        insertStyle = _styles[0];
      } else if (suffix > 0) {
        insertStyle = _styles[oldText.length - suffix];
      } else {
        insertStyle = RichStyle.plain;
      }
      _styles = [
        ..._styles.sublist(0, prefix),
        for (var i = 0; i < insertedLength; i++) insertStyle,
        ..._styles.sublist(oldText.length - suffix),
      ];
      if (insertedLength > 0 && _pendingStyle != null) {
        _pendingOffset = prefix + insertedLength;
      } else {
        _pendingStyle = null;
      }
    } else if (newValue.selection != selection &&
        (!newValue.selection.isCollapsed ||
            newValue.selection.baseOffset != _pendingOffset)) {
      _pendingStyle = null;
    }
    super.value = newValue;
  }

  /// Stil an der aktuellen Cursor-Position bzw. gemeinsamer Stil der Auswahl.
  RichStyle get currentStyle {
    final sel = selection;
    if (!sel.isValid) return RichStyle.plain;
    if (sel.isCollapsed) {
      if (_pendingStyle != null && _pendingOffset == sel.baseOffset) {
        return _pendingStyle!;
      }
      final i = sel.baseOffset;
      if (i > 0 && i <= _styles.length) return _styles[i - 1];
      return _styles.isNotEmpty ? _styles.first : RichStyle.plain;
    }
    final range = _styles.sublist(sel.start, sel.end);
    return RichStyle(
      bold: range.every((s) => s.bold),
      italic: range.every((s) => s.italic),
      color: range.every((s) => s.color == range.first.color)
          ? range.first.color
          : null,
    );
  }

  void toggleBold() {
    final on = !currentStyle.bold;
    _apply((s) => s.copyWith(bold: on));
  }

  void toggleItalic() {
    final on = !currentStyle.italic;
    _apply((s) => s.copyWith(italic: on));
  }

  void setColor(RichColor? color) =>
      _apply((s) => s.copyWith(color: () => color));

  /// Entfernt jede Formatierung aus der Auswahl.
  void clearFormatting() => _apply((_) => RichStyle.plain);

  void _apply(RichStyle Function(RichStyle) change) {
    final sel = selection;
    if (!sel.isValid) return;
    if (sel.isCollapsed) {
      _pendingStyle = change(currentStyle);
      _pendingOffset = sel.baseOffset;
    } else {
      for (var i = sel.start; i < sel.end; i++) {
        _styles[i] = change(_styles[i]);
      }
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final doc = document;
    final composing = value.composing;
    final colors = RichColors.of(context);
    if (!withComposing || !composing.isValid || composing.isCollapsed) {
      return TextSpan(
        style: style,
        children: [
          for (final s in doc.spans)
            TextSpan(text: s.text, style: s.style.toTextStyle(colors)),
        ],
      );
    }
    // Während der IME-Eingabe den Composing-Bereich unterstreichen.
    final children = <TextSpan>[];
    var offset = 0;
    for (final s in doc.spans) {
      final start = offset;
      final end = offset + s.text.length;
      offset = end;
      final base = s.style.toTextStyle(colors);
      final cs = composing.start.clamp(start, end);
      final ce = composing.end.clamp(start, end);
      if (cs > start) {
        children.add(TextSpan(text: text.substring(start, cs), style: base));
      }
      if (ce > cs) {
        children.add(
          TextSpan(
            text: text.substring(cs, ce),
            style: (base ?? const TextStyle()).copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      if (end > ce) {
        children.add(TextSpan(text: text.substring(ce, end), style: base));
      }
    }
    return TextSpan(style: style, children: children);
  }
}
