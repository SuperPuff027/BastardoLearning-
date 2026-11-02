import 'package:flutter/material.dart';

import 'rich_text.dart';

/// Farbwerte für [RichColor], passend zu Hell- und Dunkelmodus.
class RichColors {
  const RichColors(this.brightness);

  factory RichColors.of(BuildContext context) =>
      RichColors(Theme.of(context).brightness);

  final Brightness brightness;

  Color resolve(RichColor color) {
    final dark = brightness == Brightness.dark;
    return switch (color) {
      RichColor.red => dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
      RichColor.orange =>
        dark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
      RichColor.green =>
        dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      RichColor.blue =>
        dark ? const Color(0xFF82B1FF) : const Color(0xFF1565C0),
      RichColor.purple =>
        dark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A),
    };
  }

  static String label(RichColor color) => switch (color) {
    RichColor.red => 'Rot',
    RichColor.orange => 'Orange',
    RichColor.green => 'Grün',
    RichColor.blue => 'Blau',
    RichColor.purple => 'Lila',
  };
}

extension RichStyleText on RichStyle {
  TextStyle? toTextStyle(RichColors colors) {
    if (isPlain) return null;
    return TextStyle(
      fontWeight: bold ? FontWeight.bold : null,
      fontStyle: italic ? FontStyle.italic : null,
      color: color == null ? null : colors.resolve(color!),
    );
  }
}

/// Zeigt eine Kartenseite mit ihrer Formatierung an.
class RichCardText extends StatelessWidget {
  const RichCardText({
    super.key,
    required this.text,
    this.rich,
    this.style,
    this.maxLines,
    this.textAlign,
  });

  final String text;
  final String? rich;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final doc = RichDocument.decode(text, rich);
    final colors = RichColors.of(context);
    return Text.rich(
      TextSpan(
        children: [
          for (final s in doc.spans)
            TextSpan(text: s.text, style: s.style.toTextStyle(colors)),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}
