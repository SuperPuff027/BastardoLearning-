import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/import_parser.dart';
import 'widgets.dart';

/// Karten aus Excel, Word oder Text einfügen.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.setId});

  final int setId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _input = TextEditingController();
  ImportSeparator _separator = ImportSeparator.tab;

  /// Solange der Nutzer nichts gewählt hat, wird automatisch erkannt.
  bool _manualSeparator = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      if (!_manualSeparator && _input.text.trim().isNotEmpty) {
        _separator = detectSeparator(_input.text);
      }
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (mounted) showMessage(context, 'Die Zwischenablage ist leer');
      return;
    }
    _input.text = text;
  }

  Future<void> _import(ImportResult result) async {
    setState(() => _importing = true);
    final n = await ref
        .read(libraryRepositoryProvider)
        .importCards(widget.setId, result.pairs);
    if (!mounted) return;
    showMessage(context, '$n ${n == 1 ? 'Karte' : 'Karten'} importiert');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = parseImport(_input.text, _separator);
    final theme = Theme.of(context);
    final count = result.pairs.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Text importieren')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('runImport'),
            onPressed: count == 0 || _importing ? null : () => _import(result),
            child: Text(
              count == 0
                  ? 'Keine Karten erkannt'
                  : '$count ${count == 1 ? 'Karte' : 'Karten'} importieren',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Eine Karte pro Zeile: Fremdwort, Trennzeichen, Deutsch. '
            'Aus Excel kopierte Spalten sind durch Tab getrennt.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text('Trennzeichen', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ImportSeparator.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _separator == s,
                  onSelected: (_) => setState(() {
                    _separator = s;
                    _manualSeparator = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('importInput'),
            controller: _input,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'la casa\tdas Haus\ncomer\tessen',
              alignLabelWithHint: true,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Aus Zwischenablage einfügen'),
            ),
          ),
          if (result.invalidLines.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Nicht lesbar (Zeile ${result.invalidLines.join(', ')}): '
              'kein Trennzeichen oder leere Seite.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (count > 0) ...[
            const SizedBox(height: 16),
            Text('Vorschau', style: theme.textTheme.titleSmall),
            for (final p in result.pairs.take(50))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.front),
                subtitle: Text(p.back),
              ),
            if (count > 50) Text('… und ${count - 50} weitere'),
          ],
        ],
      ),
    );
  }
}
