import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/study_language.dart';
import '../../data/library_repository.dart';
import 'library_providers.dart';
import 'widgets.dart';

/// Neues Set anlegen ([setId] == null) oder bestehendes bearbeiten.
class SetFormScreen extends ConsumerStatefulWidget {
  const SetFormScreen({super.key, this.setId, this.initialFolderId});

  final int? setId;
  final int? initialFolderId;

  @override
  ConsumerState<SetFormScreen> createState() => _SetFormScreenState();
}

class _SetFormScreenState extends ConsumerState<SetFormScreen> {
  final _title = TextEditingController();
  StudyLanguage _language = StudyLanguage.es;
  int? _folderId;
  bool _tts = false;
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.setId == null;

  @override
  void initState() {
    super.initState();
    _folderId = widget.initialFolderId;
    if (_isNew) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final set = await ref.read(libraryRepositoryProvider).getSet(widget.setId!);
    if (!mounted) return;
    setState(() {
      if (set != null) {
        _title.text = set.title;
        _language = StudyLanguage.fromCode(set.language) ?? StudyLanguage.es;
        _folderId = set.folderId;
        _tts = set.ttsEnabled;
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(libraryRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_isNew) {
        final id = await repo.createSet(
          title: _title.text,
          language: _language.code,
          folderId: _folderId,
          ttsEnabled: _tts,
        );
        if (mounted) context.pushReplacement(Routes.set(id));
      } else {
        await repo.updateSet(
          widget.setId!,
          title: _title.text,
          language: _language.code,
          folderId: _folderId,
          ttsEnabled: _tts,
        );
        if (mounted) context.pop();
      }
    } on ValidationException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersProvider).value ?? const [];
    final globalTts = ref.watch(settingsProvider.select((s) => s.ttsEnabled));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Neues Set' : 'Set bearbeiten'),
        actions: [
          TextButton(
            key: const Key('saveSet'),
            onPressed: _loaded && !_saving ? _save : null,
            child: Text(_isNew ? 'Anlegen' : 'Speichern'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const Key('setTitle'),
                  controller: _title,
                  autofocus: _isNew,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Titel',
                    hintText: 'z. B. Spanisch – Essen & Trinken',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 24),
                Text('Sprache', style: Theme.of(context).textTheme.titleSmall),
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
                  onSelectionChanged: (s) =>
                      setState(() => _language = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vorderseite = ${_language.label}, Rückseite = Deutsch',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<int?>(
                  key: ValueKey('folder-$_folderId-${folders.length}'),
                  initialValue: folders.any((f) => f.folder.id == _folderId)
                      ? _folderId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Ordner',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Kein Ordner'),
                    ),
                    for (final f in folders)
                      DropdownMenuItem(
                        value: f.folder.id,
                        child: Text(f.folder.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _folderId = v),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const Key('setTts'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vorlesen (Text-to-Speech)'),
                  subtitle: Text(
                    globalTts ? 'Karten dieses Sets beim Lernen vorlesen' : 'Vorlesen ist in den Einstellungen global ausgeschaltet',
                  ),
                  value: _tts,
                  onChanged: (v) => setState(() => _tts = v),
                ),
              ],
            ),
    );
  }
}
