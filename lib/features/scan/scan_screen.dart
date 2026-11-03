import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/scan/language_guess.dart';
import '../../core/scan/lemmatizer.dart';
import '../../core/scan/word_extractor.dart';
import '../../core/study_language.dart';
import '../../data/database.dart';
import '../../data/library_repository.dart';
import '../library/widgets.dart';
import 'scan_services.dart';

enum _Step { source, text, preview }

/// Foto/Text → Karteikarten (Brief Abschnitt 3, Nr. 3, 4, 8).
///
/// 1. Foto aufnehmen, aus der Galerie wählen oder Text einfügen
/// 2. Erkannten Text prüfen und korrigieren (wichtig bei Handschrift),
///    Zielsprache wählen
/// 3. Vorschau: Wörter abhaken, Übersetzungen korrigieren, Set anlegen
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.setId});

  /// Karten an dieses Set anhängen; `null` = neues Set anlegen.
  final int? setId;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  _Step _step = _Step.source;
  bool _busy = false;
  bool _fromPhoto = false;
  String? _busyMessage;

  final _text = TextEditingController();
  final _title = TextEditingController();
  StudyLanguage _language = StudyLanguage.es;
  VocabSet? _targetSet;
  List<ExtractedWord> _words = [];
  bool _translationReady = false;

  @override
  void initState() {
    super.initState();
    _loadTarget();
  }

  Future<void> _loadTarget() async {
    if (widget.setId == null) return;
    final set = await ref.read(libraryRepositoryProvider).getSet(widget.setId!);
    if (!mounted || set == null) return;
    setState(() {
      _targetSet = set;
      _language = StudyLanguage.fromCode(set.language) ?? _language;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _run(String message, Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _busyMessage = message;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) showMessage(context, 'Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------ Schritt 1

  Future<void> _fromImage(ImageSource source) async {
    final file = await ref.read(imagePickerProvider)(source);
    if (file == null || !mounted) return;
    await _run('Text wird erkannt …', () async {
      final lines = await ref
          .read(textRecognitionProvider)
          .recognizeLines(file);
      if (!mounted) return;
      if (lines.isEmpty) {
        showMessage(context, 'Auf dem Bild wurde kein Text erkannt.');
        return;
      }
      _text.text = lines.join('\n');
      _fromPhoto = true;
      await _detectLanguage();
      setState(() => _step = _Step.text);
    });
  }

  void _fromText() {
    _fromPhoto = false;
    setState(() => _step = _Step.text);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text?.isNotEmpty ?? false) {
      _text.text = data!.text!;
      await _detectLanguage();
    } else if (mounted) {
      showMessage(context, 'Die Zwischenablage ist leer');
    }
  }

  // ------------------------------------------------------------ Schritt 2

  WordExtractor _extractor(Map<String, String> myCards) {
    final vocab = ref.read(vocabRepositoryProvider);
    return WordExtractor(
      lemmatizer: Lemmatizer(vocab.lookupForeign),
      lookupForeign: vocab.lookupForeign,
      lookupGerman: vocab.lookupGerman,
      myCards: myCards,
    );
  }

  List<String> get _lines => _text.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  /// ML-Kit-Hinweise pro Zeile (falls verfügbar) für die Spracherkennung.
  Future<Map<int, Map<String, double>>> _hints(List<String> lines) async {
    final out = <int, Map<String, double>>{};
    final id = ref.read(languageIdProvider);
    for (var i = 0; i < lines.length && i < 80; i++) {
      if (wordsOf(lines[i]).length < 3) continue;
      try {
        out[i] = await id.identify(lines[i]);
      } catch (_) {
        return out; // ML Kit nicht verfügbar → nur Heuristik
      }
    }
    return out;
  }

  Future<void> _detectLanguage() async {
    if (_targetSet != null) return; // Sprache durch das Set festgelegt
    final lines = _lines;
    if (lines.isEmpty) return;
    final ex = _extractor(const {});
    final lang = ex.dominantForeignLanguage(
      ex.segment(lines, hints: await _hints(lines)),
    );
    final detected = lang == null ? null : StudyLanguage.fromCode(lang);
    if (detected != null && mounted) setState(() => _language = detected);
  }

  Future<void> _extract() async {
    final lines = _lines;
    if (lines.isEmpty) {
      showMessage(context, 'Kein Text vorhanden');
      return;
    }
    await _run('Wörter werden erkannt …', () async {
      final myCards = await ref
          .read(libraryRepositoryProvider)
          .cardIndex(_language.code);
      final ex = _extractor(myCards);
      final segments = ex.segment(lines, hints: await _hints(lines));
      final words = ex.extract(segments, _language.code);
      bool ready;
      try {
        ready = await ref.read(translationProvider).isReady(_language.code);
      } catch (_) {
        ready = false;
      }
      if (!mounted) return;
      if (_title.text.isEmpty) {
        final d = DateTime.now();
        _title.text =
            '${_language.label} – ${_fromPhoto ? 'Foto' : 'Text'} vom ${d.day}.${d.month}.${d.year}';
      }
      setState(() {
        _words = words;
        _translationReady = ready;
        _step = _Step.preview;
      });
    });
  }

  // ------------------------------------------------------------ Schritt 3

  Future<void> _translateMissing() async {
    final service = ref.read(translationProvider);
    await _run('Übersetze offline …', () async {
      for (final w in _words.where((w) => w.back.trim().isEmpty)) {
        final t = await service.translate(_language.code, w.front);
        if (t != null) {
          w
            ..back = t
            ..source = TranslationSource.machine;
        }
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _edit(ExtractedWord w) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditWordDialog(
        front: w.front,
        back: w.back,
        languageLabel: _language.label,
      ),
    );
    if (result == null || !mounted) return;
    final (front, back) = result;
    setState(() {
      final changed = front != w.front || back != w.back;
      w
        ..front = front
        ..back = back
        ..selected = true;
      if (changed && w.source == TranslationSource.none) {
        w.source = TranslationSource.sheet;
      }
    });
  }

  Future<void> _save() async {
    final chosen = _words.where((w) => w.selected).toList();
    if (chosen.isEmpty) {
      showMessage(context, 'Keine Wörter ausgewählt');
      return;
    }
    final missing = chosen.where((w) => w.back.trim().isEmpty).length;
    if (missing > 0) {
      showMessage(
        context,
        '$missing ${missing == 1 ? 'Wort hat' : 'Wörter haben'} noch keine Übersetzung',
      );
      return;
    }
    final library = ref.read(libraryRepositoryProvider);
    await _run('Karten werden angelegt …', () async {
      final setId =
          _targetSet?.id ??
          await library.createSet(
            title: _title.text.trim().isEmpty ? 'Neues Set' : _title.text,
            language: _language.code,
          );
      await library.addVocabCards(setId, [
        for (final w in chosen)
          VocabCardData(
            front: w.front,
            back: w.back,
            vocabId: w.entry?.id,
            verified: w.verified,
          ),
      ]);
      if (!mounted) return;
      showMessage(context, '${chosen.length} Karten angelegt');
      if (_targetSet != null) {
        context.pop();
      } else {
        context.go(Routes.set(setId));
      }
    });
  }

  // ------------------------------------------------------------- Aufbau

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.source => 'Karten aus Foto oder Text',
      _Step.text => 'Text prüfen',
      _Step.preview => 'Wörter auswählen',
    };
    return PopScope(
      canPop: _step == _Step.source,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(
            () => _step = _step == _Step.preview ? _Step.text : _Step.source,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        bottomNavigationBar: _busy ? null : _bottomBar(),
        body: _busy
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_busyMessage ?? ''),
                  ],
                ),
              )
            : switch (_step) {
                _Step.source => _sourceStep(),
                _Step.text => _textStep(),
                _Step.preview => _previewStep(),
              },
      ),
    );
  }

  Widget? _bottomBar() {
    final Widget button;
    switch (_step) {
      case _Step.source:
        return null;
      case _Step.text:
        button = FilledButton.icon(
          key: const Key('extractWords'),
          onPressed: _extract,
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('Wörter erkennen'),
        );
      case _Step.preview:
        final n = _words.where((w) => w.selected).length;
        button = FilledButton.icon(
          key: const Key('saveScan'),
          onPressed: n == 0 ? null : _save,
          icon: const Icon(Icons.library_add),
          label: Text(
            _targetSet != null
                ? '$n Karten zu „${_targetSet!.title}“ hinzufügen'
                : 'Set mit $n Karten anlegen',
          ),
        );
    }
    return SafeArea(
      child: Padding(padding: const EdgeInsets.all(16), child: button),
    );
  }

  Widget _sourceStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Fotografiere eine Buchseite, ein Arbeitsblatt oder deine '
          'handgeschriebene Vokabelliste. Die App erkennt die Wörter, führt '
          'sie auf die Grundform zurück und schlägt Übersetzungen vor – '
          'alles auf dem Gerät, ohne Internet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (_targetSet != null) ...[
          const SizedBox(height: 8),
          Text(
            'Ziel: ${_targetSet!.title}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
        const SizedBox(height: 24),
        if (ref.watch(onDeviceMlAvailableProvider)) ...[
          _SourceButton(
            key: const Key('scanCamera'),
            icon: Icons.photo_camera_outlined,
            title: 'Foto aufnehmen',
            onTap: () => _fromImage(ImageSource.camera),
          ),
          _SourceButton(
            key: const Key('scanGallery'),
            icon: Icons.photo_library_outlined,
            title: 'Aus der Galerie',
            onTap: () => _fromImage(ImageSource.gallery),
          ),
        ] else
          const _LiveTextHelp(),
        _SourceButton(
          key: const Key('scanText'),
          icon: Icons.notes_outlined,
          title: ref.watch(onDeviceMlAvailableProvider)
              ? 'Text einfügen'
              : 'Kopierten Text einfügen',
          subtitle: 'Live Text, Notizen, Liedtexte, Artikel …',
          onTap: _fromText,
        ),
      ],
    );
  }

  Widget _textStep() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_fromPhoto || !ref.watch(onDeviceMlAvailableProvider))
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Prüfe den erkannten Text und korrigiere Fehler – besonders bei '
                'Handschrift. Vokabelpaare wie „la casa – das Haus“ werden mit '
                'deiner Übersetzung übernommen.',
              ),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('scanInput'),
          controller: _text,
          minLines: 8,
          maxLines: 20,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'la casa – das Haus\nAyer comimos en casa de mi abuela.',
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
        const SizedBox(height: 8),
        Text(
          'Welche Sprache sollen die Karten haben?',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<StudyLanguage>(
          segments: [
            for (final l in StudyLanguage.values)
              ButtonSegment(value: l, label: Text('${l.flag} ${l.label}')),
          ],
          selected: {_language},
          onSelectionChanged: _targetSet != null
              ? null
              : (s) => setState(() => _language = s.first),
        ),
        const SizedBox(height: 4),
        Text(
          'Nur Wörter dieser Sprache werden übernommen; Deutsch dient als Übersetzung.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _previewStep() {
    final theme = Theme.of(context);
    final selected = _words.where((w) => w.selected).length;
    final missing = _words.where((w) => w.back.trim().isEmpty).length;
    if (_words.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Keine Wörter in der gewählten Sprache gefunden. Geh zurück und '
            'prüfe Text oder Sprache.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_targetSet == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('scanTitle'),
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Name des neuen Sets',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$selected von ${_words.length} ausgewählt',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final w in _words) {
                    w.selected = !w.alreadyInCards;
                  }
                }),
                child: const Text('Alle'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final w in _words) {
                    w.selected = false;
                  }
                }),
                child: const Text('Keine'),
              ),
            ],
          ),
        ),
        if (missing > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  '$missing ohne Übersetzung – antippen zum Eintragen.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                if (_translationReady)
                  TextButton.icon(
                    key: const Key('translateMissing'),
                    onPressed: _translateMissing,
                    icon: const Icon(Icons.translate),
                    label: const Text('Offline übersetzen'),
                  ),
              ],
            ),
          ),
        for (final w in _words)
          _WordTile(
            word: w,
            onChanged: (v) => setState(() => w.selected = v),
            onTap: () => _edit(w),
          ),
      ],
    );
  }
}

/// Anleitung für Live Text (iPhone) in der Browser-Version.
class _LiveTextHelp extends StatelessWidget {
  const _LiveTextHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('liveTextHelp'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.document_scanner_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Foto zu Text mit Live Text',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Foto in der Kamera- oder Fotos-App öffnen.\n'
              '2. Unten rechts auf das Text-Symbol tippen.\n'
              '3. „Alles kopieren“ wählen.\n'
              '4. Hier auf „Kopierten Text einfügen“ tippen.',
            ),
            const SizedBox(height: 8),
            Text(
              'Live Text erkennt auch Handschrift oft gut und läuft offline '
              'auf dem iPhone (ab iPhone XS / iOS 15).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.onChanged,
    required this.onTap,
  });

  final ExtractedWord word;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = word;
    final badges = <String>[
      w.source.label,
      if (w.isNew) 'neu',
      if (w.alreadyInCards) 'schon vorhanden',
      if (w.isNoise) 'Name/Füllwort?',
      if (w.count > 1) '${w.count}×',
    ];
    return CheckboxListTile(
      key: Key('word-${w.front}'),
      value: w.selected,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      secondary: IconButton(
        tooltip: 'Bearbeiten',
        icon: const Icon(Icons.edit_outlined),
        onPressed: onTap,
      ),
      title: Text(w.front, style: theme.textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            w.back.isEmpty ? 'Übersetzung fehlt' : w.back,
            style: w.back.isEmpty
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
          if (w.example != null)
            Text(
              'auf dem Blatt: ${w.example}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 2),
          Text(badges.join(' · '), style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Dialog zum Korrigieren eines erkannten Wortes; verwaltet seine
/// Textfelder selbst (sie leben bis zum Ende der Schließ-Animation).
class _EditWordDialog extends StatefulWidget {
  const _EditWordDialog({
    required this.front,
    required this.back,
    required this.languageLabel,
  });

  final String front;
  final String back;
  final String languageLabel;

  @override
  State<_EditWordDialog> createState() => _EditWordDialogState();
}

class _EditWordDialogState extends State<_EditWordDialog> {
  late final _front = TextEditingController(text: widget.front);
  late final _back = TextEditingController(text: widget.back);

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wort bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('editFront'),
              controller: _front,
              decoration: InputDecoration(labelText: widget.languageLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('editBack'),
              controller: _back,
              autofocus: widget.back.isEmpty,
              decoration: const InputDecoration(labelText: 'Deutsch'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('editSave'),
          onPressed: () =>
              Navigator.of(context)
                  .pop((_front.text.trim(), _back.text.trim())),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
