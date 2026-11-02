import 'package:flutter/material.dart';

import 'rich_text.dart';
import 'rich_text_controller.dart';
import 'rich_text_style.dart';

/// Textfeld mit Formatierungsleiste (fett, kursiv, Farbe).
class RichTextField extends StatefulWidget {
  const RichTextField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final RichTextController controller;
  final String label;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          minLines: 1,
          maxLines: 4,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
        ),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => _Toolbar(controller: widget.controller),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final RichTextController controller;

  @override
  Widget build(BuildContext context) {
    final style = controller.currentStyle;
    final colors = RichColors.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'Fett',
          isSelected: style.bold,
          icon: const Icon(Icons.format_bold),
          onPressed: controller.toggleBold,
        ),
        IconButton(
          tooltip: 'Kursiv',
          isSelected: style.italic,
          icon: const Icon(Icons.format_italic),
          onPressed: controller.toggleItalic,
        ),
        PopupMenuButton<RichColor?>(
          tooltip: 'Farbe',
          icon: Icon(
            Icons.format_color_text,
            color: style.color == null ? null : colors.resolve(style.color!),
          ),
          onSelected: controller.setColor,
          itemBuilder: (_) => [
            const PopupMenuItem(value: null, child: Text('Standardfarbe')),
            for (final c in RichColor.values)
              PopupMenuItem(
                value: c,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: colors.resolve(c)),
                    const SizedBox(width: 12),
                    Text(RichColors.label(c)),
                  ],
                ),
              ),
          ],
        ),
        IconButton(
          tooltip: 'Formatierung entfernen',
          icon: const Icon(Icons.format_clear),
          onPressed: controller.clearFormatting,
        ),
      ],
    );
  }
}
