import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/import_parser.dart';
import '../../core/study_language.dart';
import '../../data/library_repository.dart';
import 'widgets.dart';

/// Vokabeldatei (CSV/TSV) importieren: ein Ordner mit je einem Set pro
/// Lektion, z. B. aus einer Wortschatzliste des Lehrbuchs.
class VocabFileImportScreen extends ConsumerStatefulWidget {
  const VocabFileImportScreen({super.key});

  @override
  ConsumerState<VocabFileImportScreen> createState() =>
      _VocabFileImportScreenState();
}

class _VocabFileImportScreenState extends ConsumerState<VocabFileImportScreen> {
  final _name = TextEditingController();
  VocabFile? _file;
  String? _fileName;
  StudyLanguage _language = StudyLanguage.es;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ref.read(pickVocabFileProvider)();
    if (picked == null || !mounted) return;
    final String text;
    try {
      text = utf8.decode(picked.bytes);
    } catch (_) {
      showMessage(context, 'Die Datei muss als UTF-8-Text gespeichert sein.');
      return;
    }
    final file = parseVocabFile(text);
    setState(() {
      _file = file;
      _fileName = picked.name;
      _name.text = _prettyName(picked.name);
    });
  }

  static String _prettyName(String fileName) {
    final base = fileName.replaceAll(
      RegExp(r'\.(csv|tsv|txt)$', caseSensitive: false),
      '',
    );
    final words = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return words.isEmpty
        ? 'Importierte Vokabeln'
        : words[0].toUpperCase() + words.substring(1);
  }

  Future<void> _import() async {
    final file = _file;
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final folderId = await ref
          .read(libraryRepositoryProvider)
          .importVocabFile(
            folderName: _name.text.trim().isEmpty
                ? 'Importierte Vokabeln'
                : _name.text.trim(),
            language: _language.code,
            file: file,
          );
      if (!mounted) return;
      showMessage(context, '${file.rows.length} Karten importiert');
      context.go(Routes.folder(folderId));
    } on ValidationException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = _file;
    return Scaffold(
      appBar: AppBar(title: const Text('Vokabeldatei importieren')),
      bottomNavigationBar: file == null || file.rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const Key('runFileImport'),
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.library_add),
                  label: Text('${file.rows.length} Karten importieren'),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Eine Zeile pro Karte: Fremdwort; Deutsch; Lektion (optional). '
            'Aus jeder Lektion wird ein eigenes Set, alle zusammen in einem Ordner. '
            'Trennzeichen „;“, „,“ oder Tab werden erkannt.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('pickVocabFile'),
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(_fileName ?? 'Datei auswählen'),
          ),
          if (file != null) ...[
            const SizedBox(height: 24),
            if (file.rows.isEmpty)
              Text(
                'In der Datei wurden keine Karten gefunden.',
                style: TextStyle(color: theme.colorScheme.error),
              )
            else ...[
              TextField(
                key: const Key('vocabFileFolder'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name des Ordners',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sprache der Vorderseite',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<StudyLanguage>(
                segments: [
                  for (final l in StudyLanguage.values)
                    ButtonSegment(
                      value: l,
                      label: Text('${l.flag} ${l.label}'),
                    ),
                ],
                selected: {_language},
                onSelectionChanged: (s) => setState(() => _language = s.first),
              ),
              const SizedBox(height: 16),
              Text(
                '${file.rows.length} Karten in ${file.groups.length} '
                '${file.groups.length == 1 ? 'Set' : 'Sets'}',
                style: theme.textTheme.titleSmall,
              ),
              for (final g in file.groups)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.style_outlined),
                  title: Text(g.isEmpty ? _name.text : g),
                  trailing: Text(
                    '${file.rows.where((r) => (r.group ?? '') == g).length}',
                  ),
                ),
            ],
            if (file.invalidLines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${file.invalidLines.length} Zeilen übersprungen '
                  '(Zeile ${file.invalidLines.take(10).join(', ')}'
                  '${file.invalidLines.length > 10 ? ' …' : ''}).',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
