import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/study_language.dart';
import '../../data/library_repository.dart';
import '../../data/vocab/vocab_entry.dart';
import 'widgets.dart';

/// Vorgefertigte Sets aus der Vokabeldatenbank (Brief Nr. 1 und Abschnitt 5).
class PresetSetsScreen extends ConsumerStatefulWidget {
  const PresetSetsScreen({super.key});

  @override
  ConsumerState<PresetSetsScreen> createState() => _PresetSetsScreenState();
}

class _PresetSetsScreenState extends ConsumerState<PresetSetsScreen> {
  StudyLanguage _language = StudyLanguage.es;

  static String presetTitle(StudyLanguage lang, PresetGroup g) =>
      g.tag == null ? '${lang.label} – ${g.label}' : '${lang.label} ${g.label}';

  Future<void> _open(PresetGroup group) async {
    final vocab = ref.read(vocabRepositoryProvider);
    final entries = vocab.entriesFor(group);
    final title = presetTitle(_language, group);
    final add = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PreviewSheet(title: title, entries: entries),
    );
    if (add != true || !mounted) return;

    final library = ref.read(libraryRepositoryProvider);
    final existing = (await library.getAllSets())
        .where((s) => s.set.title == title)
        .toList();
    if (existing.isNotEmpty && mounted) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set schon vorhanden'),
          content: Text('„$title“ gibt es bereits in deiner Bibliothek.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('new'),
              child: const Text('Trotzdem neu anlegen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('open'),
              child: const Text('Vorhandenes öffnen'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'open') {
        context.go(Routes.set(existing.first.set.id));
        return;
      }
    }

    final id = await library.createSet(title: title, language: _language.code);
    await library.addVocabCards(id, [
      for (final e in entries)
        VocabCardData(
          front: e.cardFront,
          back: e.cardBack,
          vocabId: e.id,
          verified: e.verified,
        ),
    ]);
    if (!mounted) return;
    showMessage(context, '${entries.length} Karten hinzugefügt');
    context.go(Routes.set(id));
  }

  @override
  Widget build(BuildContext context) {
    final vocab = ref.watch(vocabRepositoryProvider);
    final groups = vocab.presetGroups(_language.code);
    final levels = {for (final g in groups) g.cefrLevel}.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Vorgefertigte Sets')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<StudyLanguage>(
              segments: [
                for (final l in StudyLanguage.values)
                  ButtonSegment(value: l, label: Text('${l.flag} ${l.label}')),
              ],
              selected: {_language},
              onSelectionChanged: (s) => setState(() => _language = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '${vocab.count(_language.code)} Wörter, nach Häufigkeit sortiert. '
              'KI-generiert und automatisch geprüft – jede Karte lässt sich bearbeiten.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final level in levels) ...[
            SectionHeader('Niveau $level'),
            for (final g in groups.where((g) => g.cefrLevel == level))
              ListTile(
                key: Key('preset-${g.cefrLevel}-${g.tag ?? 'alle'}'),
                leading: Icon(
                  g.tag == null
                      ? Icons.auto_stories_outlined
                      : Icons.label_outline,
                ),
                title: Text(g.label),
                subtitle: Text('${g.count} Wörter'),
                trailing: const Icon(Icons.add),
                onTap: () => _open(g),
              ),
          ],
        ],
      ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.title, required this.entries});

  final String title;
  final List<VocabEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('${entries.length} Karten'),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in entries.take(30))
                    ListTile(
                      dense: true,
                      title: Text(e.cardFront),
                      subtitle: Text(e.cardBack),
                      trailing: e.verified
                          ? null
                          : const Text(
                              'unbestätigt',
                              style: TextStyle(fontSize: 11),
                            ),
                    ),
                  if (entries.length > 30)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '… und ${entries.length - 30} weitere',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                key: const Key('addPreset'),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.library_add),
                label: const Text('Als Set hinzufügen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
