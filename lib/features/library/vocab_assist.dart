import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/library_repository.dart';
import '../../data/vocab/vocab_entry.dart';

/// Hinweise beim manuellen Anlegen/Bearbeiten einer Karte:
/// - Karte gibt es schon (in diesem oder einem anderen Set)
/// - Wort steht in der Vokabeldatenbank → übernehmen oder verwerfen
/// - Vorschläge beim Tippen (Brief Nr. 4)
class VocabAssist extends ConsumerStatefulWidget {
  const VocabAssist({
    super.key,
    required this.setId,
    required this.language,
    required this.front,
    required this.back,
    required this.linkedVocabId,
    required this.isNewCard,
    this.cardId,
    required this.onAdopt,
    required this.onDiscard,
    required this.onDeleteThis,
    required this.onOpenCard,
  });

  final int setId;
  final String language;
  final TextEditingController front;
  final TextEditingController back;
  final int? linkedVocabId;
  final bool isNewCard;
  final int? cardId;
  final ValueChanged<VocabEntry> onAdopt;

  /// Neue Karte verwerfen (Felder leeren).
  final VoidCallback onDiscard;

  /// Bestehende Karte löschen.
  final VoidCallback onDeleteThis;
  final ValueChanged<DuplicateHit> onOpenCard;

  @override
  ConsumerState<VocabAssist> createState() => _VocabAssistState();
}

class _VocabAssistState extends ConsumerState<VocabAssist> {
  Timer? _debounce;
  List<DuplicateHit> _duplicates = const [];
  List<VocabEntry> _matches = const [];
  List<VocabEntry> _suggestions = const [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.front.addListener(_schedule);
    widget.back.addListener(_schedule);
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.front.removeListener(_schedule);
    widget.back.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _refresh);
  }

  Future<void> _refresh() async {
    final gen = ++_generation;
    final front = widget.front.text.trim();
    final back = widget.back.text.trim();
    final vocab = ref.read(vocabRepositoryProvider);
    final lang = widget.language;

    var matches = <VocabEntry>[];
    var suggestions = <VocabEntry>[];
    if (front.isNotEmpty) {
      matches = vocab.lookupForeign(lang, front);
      if (matches.isEmpty) suggestions = vocab.suggestForeign(lang, front);
    } else if (back.isNotEmpty) {
      matches = vocab.lookupGerman(lang, back);
      if (matches.isEmpty) suggestions = vocab.suggestGerman(lang, back);
    }
    final duplicates = front.isEmpty
        ? const <DuplicateHit>[]
        : await ref
              .read(libraryRepositoryProvider)
              .findDuplicates(
                lang,
                front,
                excludeCardId: widget.cardId,
                preferSetId: widget.setId,
              );
    if (!mounted || gen != _generation) return;
    setState(() {
      _duplicates = duplicates;
      _matches = matches.take(2).toList();
      _suggestions = suggestions;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sameSet = _duplicates.where((d) => d.set.id == widget.setId).toList();
    final otherSets = _duplicates
        .where((d) => d.set.id != widget.setId)
        .map((d) => d.set.title)
        .toSet()
        .toList();
    final children = <Widget>[];

    if (sameSet.isNotEmpty) {
      final d = sameSet.first;
      children.add(
        _Banner(
          key: const Key('duplicateBanner'),
          icon: Icons.content_copy,
          color: theme.colorScheme.error,
          title: 'Schon in diesem Set',
          text: '${d.card.front} – ${d.card.back}',
          actions: [
            TextButton(
              onPressed: () => widget.onOpenCard(d),
              child: const Text('Ansehen'),
            ),
            FilledButton.tonal(
              key: const Key('discardDuplicate'),
              onPressed: widget.isNewCard
                  ? widget.onDiscard
                  : widget.onDeleteThis,
              child: Text(
                widget.isNewCard ? 'Verwerfen' : 'Diese Karte löschen',
              ),
            ),
          ],
        ),
      );
    }
    if (otherSets.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Auch in: ${otherSets.join(', ')}',
            key: const Key('otherSetsHint'),
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    for (final m in _matches) {
      final linked = m.id == widget.linkedVocabId;
      final manual = widget.linkedVocabId == null;
      children.add(
        _Banner(
          key: Key('vocabMatch-${m.id}'),
          icon: linked ? Icons.verified_outlined : Icons.menu_book_outlined,
          color: linked ? Colors.green : theme.colorScheme.primary,
          title: linked
              ? 'Mit der Vokabeldatenbank verknüpft'
              : 'Schon in der Vokabeldatenbank',
          subtitle:
              '${m.cefrLevel} · ${m.posLabel}'
              '${m.verified ? '' : ' · unbestätigt'}',
          text: '${m.cardFront} – ${m.translations.join(', ')}',
          detail: m.example.isEmpty
              ? null
              : '${m.example}\n${m.exampleTranslation}',
          actions: [
            if (!linked)
              FilledButton.tonal(
                key: const Key('adoptVocab'),
                onPressed: () => widget.onAdopt(m),
                child: const Text('Übernehmen'),
              ),
            if (!linked && manual)
              TextButton(
                key: const Key('discardBecauseInVocab'),
                onPressed: widget.isNewCard
                    ? widget.onDiscard
                    : widget.onDeleteThis,
                child: Text(widget.isNewCard ? 'Verwerfen' : 'Karte löschen'),
              ),
          ],
        ),
      );
    }

    if (_suggestions.isNotEmpty) {
      children.add(
        Text(
          'Vorschläge aus der Vokabeldatenbank',
          style: theme.textTheme.labelMedium,
        ),
      );
      children.add(const SizedBox(height: 4));
      children.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in _suggestions)
              ActionChip(
                key: Key('suggestion-${s.id}'),
                label: Text('${s.cardFront} – ${s.translations.first}'),
                onPressed: () => widget.onAdopt(s),
              ),
          ],
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.subtitle,
    this.detail,
    this.actions = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String text;
  final String? detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(text, style: theme.textTheme.bodyLarge),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(detail!, style: theme.textTheme.bodySmall),
            ],
            if (actions.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}
