import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/placeholder_view.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/rich_text_style.dart';
import '../../core/study_language.dart';
import '../../data/database.dart';
import '../../data/library_repository.dart';
import '../study/study_options.dart';
import 'library_providers.dart';
import 'widgets.dart';

class SetDetailScreen extends ConsumerStatefulWidget {
  const SetDetailScreen({super.key, required this.setId});

  final int setId;

  @override
  ConsumerState<SetDetailScreen> createState() => _SetDetailScreenState();
}

class _SetDetailScreenState extends ConsumerState<SetDetailScreen> {
  bool _starredOnly = false;

  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    final set = ref.watch(setProvider(widget.setId));
    final allCards = ref.watch(
      cardsProvider((setId: widget.setId, starredOnly: false)),
    );

    return AsyncBody(
      value: set,
      data: (s) {
        if (s == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const PlaceholderView(
              icon: Icons.style_outlined,
              title: 'Set nicht gefunden',
              message: 'Dieses Set wurde gelöscht.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(s.title), actions: [_menu(s)]),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('addCard'),
            onPressed: () => context.go(Routes.newCard(s.id)),
            icon: const Icon(Icons.add),
            label: const Text('Karte'),
          ),
          body: AsyncBody(
            value: allCards,
            data: (cards) {
              final starredCount = cards.where((c) => c.starred).length;
              final visible = _starredOnly
                  ? cards.where((c) => c.starred).toList()
                  : cards;
              final duplicates = LibraryRepository.duplicateIdsIn(cards);
              return ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  _Header(
                    set: s,
                    cardCount: cards.length,
                    starredCount: starredCount,
                    starredOnly: _starredOnly,
                    onStarredOnlyChanged: (v) =>
                        setState(() => _starredOnly = v),
                  ),
                  if (cards.isNotEmpty)
                    _StudyModes(
                      onMode: (mode) =>
                          _startMode(s, mode, cards.length, starredCount),
                      onReview: () => context.push(Routes.review(setId: s.id)),
                    ),
                  if (cards.isEmpty)
                    _EmptyCards(setId: s.id)
                  else if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Keine markierten Karten. Tippe auf den Stern einer Karte, um sie zu markieren.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final c in visible)
                      _CardTile(
                        card: c,
                        isDuplicate: duplicates.contains(c.id),
                        onTap: () => context.go(Routes.card(s.id, c.id)),
                        onStar: () => _repo.setStarred(c.id, !c.starred),
                        onDelete: () => _deleteCard(c),
                      ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _menu(VocabSet s) => PopupMenuButton<String>(
    key: const Key('setMenu'),
    onSelected: (v) => switch (v) {
      'edit' => context.go(Routes.editSet(s.id)),
      'import' => context.go(Routes.importCards(s.id)),
      'move' => _move(s),
      'copy' => _copy(s),
      'merge' => _merge(s),
      'delete' => _delete(s),
      _ => null,
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit_outlined),
          title: Text('Bearbeiten'),
        ),
      ),
      PopupMenuItem(
        value: 'import',
        child: ListTile(
          leading: Icon(Icons.content_paste_go_outlined),
          title: Text('Text importieren'),
        ),
      ),
      PopupMenuItem(
        value: 'scan',
        child: ListTile(
          leading: Icon(Icons.document_scanner_outlined),
          title: Text('Aus Foto oder Text'),
        ),
      ),
      PopupMenuItem(
        value: 'move',
        child: ListTile(
          leading: Icon(Icons.drive_file_move_outlined),
          title: Text('In Ordner verschieben'),
        ),
      ),
      PopupMenuItem(
        value: 'copy',
        child: ListTile(
          leading: Icon(Icons.copy_outlined),
          title: Text('Kopieren'),
        ),
      ),
      PopupMenuItem(
        value: 'merge',
        child: ListTile(
          leading: Icon(Icons.merge_outlined),
          title: Text('Zusammenführen'),
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete_outline),
          title: Text('Löschen'),
        ),
      ),
    ],
  );

  Future<void> _startMode(
    VocabSet s,
    StudyModeKind mode,
    int cardCount,
    int starredCount,
  ) async {
    final settings = ref.read(settingsProvider);
    final options = await showStudyOptionsSheet(
      context,
      mode: mode,
      initial: StudyOptions(
        direction: settings.quizDirection,
        starredOnly: _starredOnly && starredCount > 0,
      ),
      cardCount: cardCount,
      starredCount: starredCount,
    );
    if (options == null || !mounted) return;
    await context.push(Routes.study(s.id, mode, options));
  }

  Future<void> _deleteCard(VocabCard c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Karte löschen?',
      message: '„${c.front}“ wird gelöscht.',
    );
    if (ok) await _repo.deleteCard(c.id);
  }

  Future<void> _move(VocabSet s) async {
    final folders = await _repo.getFolders();
    if (!mounted) return;
    // -1 = kein Ordner, -2 = neuer Ordner
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('In Ordner verschieben'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(-1),
            child: ListTile(
              leading: const Icon(Icons.layers_clear_outlined),
              title: const Text('Kein Ordner'),
              selected: s.folderId == null,
            ),
          ),
          for (final f in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(f.folder.id),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f.folder.name),
                selected: s.folderId == f.folder.id,
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(-2),
            child: const ListTile(
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('Neuer Ordner …'),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    int? folderId = choice == -1 ? null : choice;
    if (choice == -2) {
      final name = await showNameDialog(
        context,
        title: 'Neuer Ordner',
        confirm: 'Anlegen',
      );
      if (name == null) return;
      folderId = await _repo.createFolder(name);
    }
    await _repo.moveSetToFolder(s.id, folderId);
    if (mounted) showMessage(context, 'Set verschoben');
  }

  Future<void> _copy(VocabSet s) async {
    final id = await _repo.copySet(s.id);
    if (!mounted) return;
    showMessage(context, 'Kopie angelegt');
    context.go(Routes.set(id));
  }

  Future<void> _merge(VocabSet s) async {
    final all = await _repo.getAllSets();
    final candidates = all
        .where((x) => x.set.id != s.id && x.set.language == s.language)
        .toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      showMessage(
        context,
        'Keine weiteren ${StudyLanguage.labelFor(s.language)}-Sets zum Zusammenführen',
      );
      return;
    }
    final result = await showDialog<({List<int> ids, bool deleteSources})>(
      context: context,
      builder: (_) => _MergeDialog(target: s, candidates: candidates),
    );
    if (result == null || result.ids.isEmpty || !mounted) return;
    try {
      final n = await _repo.mergeSets(
        s.id,
        result.ids,
        deleteSources: result.deleteSources,
      );
      if (mounted) {
        showMessage(context, '$n ${n == 1 ? 'Karte' : 'Karten'} übernommen');
      }
    } on ValidationException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _delete(VocabSet s) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Set löschen?',
      message:
          '„${s.title}“ und alle Karten darin werden gelöscht. Das kann nicht rückgängig gemacht werden.',
    );
    if (!ok || !mounted) return;
    final folderId = s.folderId;
    context.go(folderId == null ? Routes.library : Routes.folder(folderId));
    await _repo.deleteSet(s.id);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.set,
    required this.cardCount,
    required this.starredCount,
    required this.starredOnly,
    required this.onStarredOnlyChanged,
  });

  final VocabSet set;
  final int cardCount;
  final int starredCount;
  final bool starredOnly;
  final ValueChanged<bool> onStarredOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final lang = StudyLanguage.fromCode(set.language);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${lang?.flag ?? ''} ${StudyLanguage.labelFor(set.language)} ↔ Deutsch · '
            '$cardCount ${cardCount == 1 ? 'Karte' : 'Karten'}',
            style: theme.textTheme.bodyMedium,
          ),
          if (set.ttsEnabled) const Icon(Icons.volume_up_outlined, size: 18),
          FilterChip(
            key: const Key('starredFilter'),
            avatar: const Icon(Icons.star, size: 18),
            label: Text('Nur markierte ($starredCount)'),
            selected: starredOnly,
            onSelected: onStarredOnlyChanged,
          ),
        ],
      ),
    );
  }
}

class _StudyModes extends StatelessWidget {
  const _StudyModes({required this.onMode, required this.onReview});

  final ValueChanged<StudyModeKind> onMode;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in StudyModeKind.values)
            ActionChip(
              key: Key('mode-${m.name}'),
              avatar: Icon(m.icon, size: 18),
              label: Text(m.label),
              onPressed: () => onMode(m),
            ),
          ActionChip(
            key: const Key('mode-review'),
            avatar: const Icon(Icons.replay, size: 18),
            label: const Text('Wiederholen'),
            onPressed: onReview,
          ),
        ],
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.setId});

  final int setId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.style_outlined, size: 56),
          const SizedBox(height: 12),
          const Text('Noch keine Karten in diesem Set.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => context.go(Routes.newCard(setId)),
                icon: const Icon(Icons.add),
                label: const Text('Karte hinzufügen'),
              ),
              OutlinedButton.icon(
                key: const Key('emptyScan'),
                onPressed: () => context.push(Routes.scan(setId: setId)),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Aus Foto oder Text'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.importCards(setId)),
                icon: const Icon(Icons.content_paste_go_outlined),
                label: const Text('Text importieren'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    this.isDuplicate = false,
    required this.onTap,
    required this.onStar,
    required this.onDelete,
  });

  final VocabCard card;
  final bool isDuplicate;
  final VoidCallback onTap;
  final VoidCallback onStar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichCardText(
                      text: card.front,
                      rich: card.frontRich,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    RichCardText(
                      text: card.back,
                      rich: card.backRich,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (isDuplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ActionChip(
                          key: Key('duplicateChip-${card.id}'),
                          avatar: const Icon(Icons.content_copy, size: 16),
                          label: const Text('doppelt – löschen'),
                          visualDensity: VisualDensity.compact,
                          onPressed: onDelete,
                        ),
                      ),
                    if (!card.verified)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'unbestätigt',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (card.imagePath != null) ...[
                const SizedBox(width: 8),
                CardImage(path: card.imagePath!, size: 56),
              ],
              IconButton(
                tooltip: card.starred ? 'Markierung entfernen' : 'Markieren',
                onPressed: onStar,
                icon: Icon(
                  card.starred ? Icons.star : Icons.star_border,
                  color: card.starred ? Colors.amber : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MergeDialog extends StatefulWidget {
  const _MergeDialog({required this.target, required this.candidates});

  final VocabSet target;
  final List<SetWithCount> candidates;

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  final _selected = <int>{};
  bool _deleteSources = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('In „${widget.target.title}“ zusammenführen'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Karten aus diesen Sets übernehmen:'),
            for (final c in widget.candidates)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(c.set.id),
                title: Text(c.set.title),
                subtitle: Text('${c.cardCount} Karten'),
                onChanged: (v) => setState(
                  () => v == true
                      ? _selected.add(c.set.id)
                      : _selected.remove(c.set.id),
                ),
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _deleteSources,
              title: const Text('Ausgewählte Sets danach löschen'),
              onChanged: (v) => setState(() => _deleteSources = v),
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
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop((ids: _selected.toList(), deleteSources: _deleteSources)),
          child: const Text('Zusammenführen'),
        ),
      ],
    );
  }
}
