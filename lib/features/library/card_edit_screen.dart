import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../core/rich_text.dart';
import '../../core/rich_text_controller.dart';
import '../../core/rich_text_field.dart';
import '../../core/study_language.dart';
import '../../data/library_repository.dart';
import '../../data/media/media_store.dart';
import '../../data/vocab/vocab_entry.dart';
import '../../app/router.dart';
import 'vocab_assist.dart';
import 'widgets.dart';

/// Karte anlegen ([cardId] == null) oder bearbeiten.
class CardEditScreen extends ConsumerStatefulWidget {
  const CardEditScreen({super.key, required this.setId, this.cardId});

  final int setId;
  final int? cardId;

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  final _front = RichTextController();
  final _back = RichTextController();
  final _frontFocus = FocusNode();
  String _languageLabel = 'Fremdwort';
  String? _languageCode;

  /// Verknüpfter Eintrag der Vokabeldatenbank (übernommen oder geladen).
  VocabEntry? _vocabEntry;
  int? _lastLinkedId;

  /// Bild beim Öffnen (bereits gespeichert).
  String? _savedImage;

  /// Aktuell angezeigtes Bild.
  String? _image;
  bool _starred = false;
  bool _verified = true;
  bool _loaded = false;
  bool _saving = false;
  int _addedCount = 0;

  bool get _isNew => widget.cardId == null;
  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);

  /// In initState gemerkt, weil `ref` in dispose() nicht mehr nutzbar ist.
  late final MediaStore _media;

  @override
  void initState() {
    super.initState();
    _media = ref.read(mediaStoreProvider);
    // Verknüpfungsanzeige aktualisieren, wenn die Vorderseite sich ändert.
    _front.addListener(() {
      final id = _linkedEntry?.id;
      if (id != _lastLinkedId && mounted) setState(() => _lastLinkedId = id);
    });
    _load();
  }

  Future<void> _load() async {
    final set = await _repo.getSet(widget.setId);
    final card = _isNew ? null : await _repo.getCard(widget.cardId!);
    if (!mounted) return;
    setState(() {
      if (set != null) {
        _languageLabel = StudyLanguage.labelFor(set.language);
        _languageCode = set.language;
      }
      if (card?.vocabId != null) {
        _vocabEntry = ref.read(vocabRepositoryProvider).byId(card!.vocabId!);
      }
      if (card != null) {
        _front.document = RichDocument.decode(card.front, card.frontRich);
        _back.document = RichDocument.decode(card.back, card.backRich);
        _savedImage = card.imagePath;
        _image = card.imagePath;
        _starred = card.starred;
        _verified = card.verified;
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    // Neu gewähltes, aber nicht gespeichertes Bild aufräumen.
    if (_image != null && _image != _savedImage) {
      _media.delete(_image);
    }
    _front.dispose();
    _back.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ref.read(imagePickerProvider)(source);
    if (file == null) return;
    final path = await _media.importBytes(
      file.bytes,
      extension: file.extension,
    );
    if (!mounted) {
      await _media.delete(path);
      return;
    }
    _discardUnsavedImage();
    setState(() => _image = path);
  }

  void _removeImage() {
    _discardUnsavedImage();
    setState(() => _image = null);
  }

  void _discardUnsavedImage() {
    if (_image != null && _image != _savedImage) {
      _media.delete(_image);
    }
  }

  /// Verknüpfung bleibt nur, solange die Vorderseite zum Eintrag passt.
  VocabEntry? get _linkedEntry {
    final e = _vocabEntry;
    if (e == null) return null;
    final key = duplicateKey(_front.text);
    final matches =
        key == duplicateKey(e.cardFront) ||
        key == duplicateKey(e.lemma) ||
        e.forms.any((f) => duplicateKey(f) == key);
    return matches ? e : null;
  }

  void _adopt(VocabEntry entry) {
    setState(() {
      _front.document = RichDocument.plain(entry.cardFront);
      _back.document = RichDocument.plain(entry.cardBack);
      _vocabEntry = entry;
    });
  }

  /// Neue Karte verwerfen: im Serienmodus Felder leeren, sonst schließen.
  void _discard() {
    if (_addedCount > 0) {
      setState(() {
        _front.document = RichDocument.plain('');
        _back.document = RichDocument.plain('');
        _vocabEntry = null;
      });
      _discardUnsavedImage();
      setState(() => _image = null);
      _frontFocus.requestFocus();
      showMessage(context, 'Karte verworfen');
    } else {
      context.pop();
      showMessage(context, 'Karte verworfen');
    }
  }

  Future<void> _save({bool next = false}) async {
    setState(() => _saving = true);
    final linked = _linkedEntry;
    final draft = CardDraft(
      front: _front.document,
      back: _back.document,
      imagePath: _image,
      starred: _starred,
      vocabId: linked?.id,
      verified: linked?.verified ?? true,
    );
    try {
      if (_isNew) {
        await _repo.addCard(widget.setId, draft);
      } else {
        await _repo.updateCard(widget.cardId!, draft);
      }
      _savedImage = _image;
      if (!mounted) return;
      if (next) {
        setState(() {
          _addedCount++;
          _front.document = RichDocument.plain('');
          _back.document = RichDocument.plain('');
          _image = null;
          _savedImage = null;
          _starred = false;
          _vocabEntry = null;
        });
        _frontFocus.requestFocus();
        showMessage(context, 'Karte gespeichert');
      } else {
        context.pop();
      }
    } on ValidationException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Karte löschen?',
      message: 'Die Karte wird gelöscht.',
    );
    if (!ok) return;
    await _repo.deleteCard(widget.cardId!);
    _savedImage = _image; // Datei wurde vom Repository entfernt
    _image = null;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNew
        ? (_addedCount == 0 ? 'Neue Karte' : 'Neue Karte (${_addedCount + 1})')
        : 'Karte bearbeiten';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _starred ? 'Markierung entfernen' : 'Markieren',
            onPressed: () => setState(() => _starred = !_starred),
            icon: Icon(
              _starred ? Icons.star : Icons.star_border,
              color: _starred ? Colors.amber : null,
            ),
          ),
          if (!_isNew)
            IconButton(
              tooltip: 'Löschen',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_verified)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Diese Übersetzung ist unbestätigt. Mit „Speichern“ bestätigst du sie.',
                    ),
                  ),
                RichTextField(
                  key: const Key('frontField'),
                  controller: _front,
                  focusNode: _frontFocus,
                  autofocus: _isNew,
                  label: 'Vorderseite ($_languageLabel)',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RichTextField(
                  key: const Key('backField'),
                  controller: _back,
                  label: 'Rückseite (Deutsch)',
                ),
                if (_languageCode != null)
                  VocabAssist(
                    setId: widget.setId,
                    language: _languageCode!,
                    front: _front,
                    back: _back,
                    linkedVocabId: _linkedEntry?.id,
                    isNewCard: _isNew,
                    cardId: widget.cardId,
                    onAdopt: _adopt,
                    onDiscard: _discard,
                    onDeleteThis: _delete,
                    onOpenCard: (hit) =>
                        context.go(Routes.card(hit.set.id, hit.card.id)),
                  ),
                const SizedBox(height: 16),
                _ImageSection(
                  image: _image,
                  onPick: _pickImage,
                  onRemove: _removeImage,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('saveCard'),
                  onPressed: _saving ? null : () => _save(),
                  child: const Text('Speichern'),
                ),
                if (_isNew) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('saveCardNext'),
                    onPressed: _saving ? null : () => _save(next: true),
                    child: const Text('Speichern & nächste Karte'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  final String? image;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => onPick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Foto aufnehmen'),
          ),
          OutlinedButton.icon(
            onPressed: () => onPick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Aus Galerie'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: CardImage(path: image!, fit: BoxFit.contain),
        ),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Bild entfernen'),
        ),
      ],
    );
  }
}
