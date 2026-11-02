import 'package:flutter/material.dart';

import '../../core/learning/grading.dart';
import '../../core/learning/study_item.dart';
import '../../core/rich_text_style.dart';
import '../library/widgets.dart';

/// Zeigt eine Seite einer Karte groß an. Das Bild gehört zur deutschen
/// Seite (es zeigt die Bedeutung) und erscheint nur dort.
class CardSideView extends StatelessWidget {
  const CardSideView({
    super.key,
    required this.card,
    required this.foreignSide,
    this.label,
  });

  final StudyCard card;

  /// true = Fremdwort-Seite, false = deutsche Seite.
  final bool foreignSide;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = foreignSide ? card.front : card.back;
    final rich = foreignSide ? card.frontRich : card.backRich;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              label!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        RichCardText(
          text: text,
          rich: rich,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        if (!foreignSide && card.imagePath != null) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: CardImage(path: card.imagePath!, fit: BoxFit.contain),
          ),
        ],
      ],
    );
  }
}

/// Frage-Karte: Prompt der Richtung entsprechend.
class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.card,
    required this.direction,
    required this.languageLabel,
  });

  final StudyCard card;
  final AskDirection direction;
  final String languageLabel;

  @override
  Widget build(BuildContext context) {
    final foreign = direction == AskDirection.foreignToGerman;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Center(
          child: CardSideView(
            card: card,
            foreignSide: foreign,
            label: foreign
                ? '$languageLabel → Deutsch'
                : 'Deutsch → $languageLabel',
          ),
        ),
      ),
    );
  }
}

/// Fortschrittsbalken unter der AppBar.
PreferredSizeWidget progressBar(double value) => PreferredSize(
  preferredSize: const Size.fromHeight(4),
  child: LinearProgressIndicator(value: value.clamp(0, 1)),
);

/// Sonderzeichen der Sprache zum Antippen (für Tastaturen ohne Akzente).
class SpecialCharsBar extends StatelessWidget {
  const SpecialCharsBar({
    super.key,
    required this.language,
    required this.controller,
  });

  final String language;
  final TextEditingController controller;

  static const chars = {
    'es': ['á', 'é', 'í', 'ó', 'ú', 'ñ', 'ü', '¿', '¡'],
    'tr': ['ç', 'ğ', 'ı', 'İ', 'ö', 'ş', 'ü'],
  };

  void _insert(String ch) {
    final v = controller.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, ch);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + ch.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = chars[language];
    if (list == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final c in list)
          ActionChip(
            label: Text(c),
            visualDensity: VisualDensity.compact,
            onPressed: () => _insert(c),
          ),
      ],
    );
  }
}

/// Rückmeldung nach einer Antwort.
class AnswerFeedback extends StatelessWidget {
  const AnswerFeedback({
    super.key,
    required this.accepted,
    required this.expected,
    this.given,
    this.grade,
    this.overridden = false,
    this.onOverride,
  });

  final bool accepted;
  final String expected;
  final String? given;
  final GradeResult? grade;
  final bool overridden;

  /// „Ich hatte recht“, nur bei falschen Antworten.
  final VoidCallback? onOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final almost = grade?.verdict == Verdict.almostCorrect && !overridden;
    final (color, icon, title) = overridden
        ? (Colors.green, Icons.check_circle, 'Als richtig gewertet')
        : !accepted
        ? (theme.colorScheme.error, Icons.cancel, 'Falsch')
        : almost
        ? (Colors.orange, Icons.check_circle_outline, 'Fast richtig')
        : (Colors.green, Icons.check_circle, 'Richtig');
    return Card(
      key: const Key('answerFeedback'),
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (almost && grade?.hint != null) ...[
              const SizedBox(height: 4),
              Text(grade!.hint!),
            ],
            if (!accepted || almost) ...[
              const SizedBox(height: 8),
              Text('Richtige Antwort:', style: theme.textTheme.labelMedium),
              Text(expected, style: theme.textTheme.titleMedium),
            ],
            if (given != null &&
                (!accepted || almost) &&
                given!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Deine Antwort:', style: theme.textTheme.labelMedium),
              Text(given!),
            ],
            if (!accepted && onOverride != null && !overridden)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('overrideAnswer'),
                  onPressed: onOverride,
                  child: const Text('Ich hatte recht'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Abschluss einer Sitzung.
class SessionSummary extends StatelessWidget {
  const SessionSummary({
    super.key,
    required this.title,
    required this.lines,
    this.retryLabel,
    this.onRetry,
    required this.onDone,
    this.children = const [],
  });

  final String title;
  final List<String> lines;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final VoidCallback onDone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        for (final l in lines)
          Text(
            l,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        const SizedBox(height: 16),
        ...children,
        const SizedBox(height: 24),
        if (onRetry != null && retryLabel != null) ...[
          FilledButton(
            key: const Key('retryButton'),
            onPressed: onRetry,
            child: Text(retryLabel!),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          key: const Key('doneButton'),
          onPressed: onDone,
          child: const Text('Fertig'),
        ),
      ],
    );
  }
}

/// Lade- und Leerzustand für Lernsitzungen.
class StudyEmpty extends StatelessWidget {
  const StudyEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

/// Text-Eingabe für geschriebene Antworten.
class WrittenAnswerInput extends StatelessWidget {
  const WrittenAnswerInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.answerLanguage,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  /// Sprachcode der erwarteten Antwort (`de` für Deutsch).
  final String answerLanguage;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('answerInput'),
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 8),
        SpecialCharsBar(language: answerLanguage, controller: controller),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('checkAnswer'),
          onPressed: onSubmit,
          child: const Text('Prüfen'),
        ),
      ],
    );
  }
}
