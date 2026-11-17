import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/placeholder_view.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/study_language.dart';
import '../../data/library_repository.dart';
import 'library_providers.dart';
import 'widgets.dart';

/// Tab „Sets“: Kursordner ganz oben, darunter eigene Ordner und Sets.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Sprachfilter für die Kursordner (`null` = alle).
  String? _language;

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(foldersProvider);
    final sets = ref.watch(setsInFolderProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Meine Sets')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('libraryAdd'),
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Neu'),
      ),
      body: AsyncBody(
        value: folders,
        data: (folderList) => AsyncBody(
          value: sets,
          data: (setList) {
            if (folderList.isEmpty && setList.isEmpty) {
              return const PlaceholderView(
                icon: Icons.collections_bookmark_outlined,
                title: 'Noch keine Sets',
                message: 'Tippe auf „Neu“: selbst anlegen, Kursordner hinzufügen oder aus einem Foto bzw. Text.',
              );
            }
            final courses = folderList.where((f) => f.isCourse).toList();
            final own = folderList.where((f) => !f.isCourse).toList();
            final languages = {for (final c in courses) c.folder.language ?? ''}
                .where((l) => l.isNotEmpty)
                .toList();
            final shown = _language == null
                ? courses
                : courses.where((c) => c.folder.language == _language);
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (courses.isNotEmpty) ...[
                  const SectionHeader('Kurse'),
                  if (languages.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            key: const Key('courseFilterAll'),
                            label: const Text('Alle'),
                            selected: _language == null,
                            onSelected: (_) => setState(() => _language = null),
                          ),
                          for (final l in languages)
                            ChoiceChip(
                              key: Key('courseFilter_$l'),
                              label: Text(StudyLanguage.labelFor(l)),
                              selected: _language == l,
                              onSelected: (_) => setState(() => _language = l),
                            ),
                        ],
                      ),
                    ),
                  for (final c in shown) CourseFolderTile(item: c),
                ],
                if (own.isNotEmpty) ...[
                  SectionHeader(courses.isEmpty ? 'Ordner' : 'Eigene Ordner'),
                  for (final f in own)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(f.folder.name),
                      subtitle: Text(
                        '${f.setCount} ${f.setCount == 1 ? 'Set' : 'Sets'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(Routes.folder(f.folder.id)),
                    ),
                ],
                if (setList.isNotEmpty) ...[
                  SectionHeader(
                    folderList.isEmpty ? 'Sets' : 'Sets ohne Ordner',
                  ),
                  for (final s in setList)
                    SetTile(
                      item: s,
                      onTap: () => context.go(Routes.set(s.set.id)),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.style_outlined),
                title: const Text('Neues Set'),
                onTap: () => Navigator.of(context).pop('set'),
              ),
              ListTile(
                key: const Key('createScan'),
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Aus Foto oder Text'),
                subtitle: const Text('Wörter erkennen, auch handgeschrieben'),
                onTap: () => Navigator.of(context).pop('scan'),
              ),
              ListTile(
                key: const Key('createCourse'),
                leading: const Icon(Icons.auto_stories_outlined),
                title: const Text('Kursordner hinzufügen'),
                subtitle: const Text(
                  'Gelöschte Lehrbuch- oder Niveau-Ordner zurückholen',
                ),
                onTap: () => Navigator.of(context).pop('course'),
              ),
              ListTile(
                key: const Key('createFromFile'),
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Vokabeldatei importieren'),
                subtitle: const Text(
                  'CSV mit Lektionen, z. B. Wortschatz aus dem Lehrbuch',
                ),
                onTap: () => Navigator.of(context).pop('file'),
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('Neuer Ordner'),
                onTap: () => Navigator.of(context).pop('folder'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'set':
        context.go(Routes.newSet());
      case 'course':
        await _addCourse(context);
      case 'file':
        context.go(Routes.vocabFile);
      case 'scan':
        context.push(Routes.scan());
      case 'folder':
        final name = await showNameDialog(
          context,
          title: 'Neuer Ordner',
          confirm: 'Anlegen',
        );
        if (name == null) return;
        try {
          await ref.read(libraryRepositoryProvider).createFolder(name);
        } on ValidationException catch (e) {
          if (context.mounted) showMessage(context, e.message);
        }
    }
  }

  Future<void> _addCourse(BuildContext context) async {
    final installer = ref.read(courseInstallerProvider);
    final missing = await installer.missing();
    if (!context.mounted) return;
    if (missing.isEmpty) {
      showMessage(context, 'Alle Kursordner sind schon da');
      return;
    }
    final key = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in missing)
                ListTile(
                  key: Key('addCourse_${c.key}'),
                  leading: LanguageBadge(code: c.language),
                  title: Text(c.title),
                  subtitle: Text(
                    '${c.setCount} Sets · ${c.cardCount} Karten\n${c.subtitle}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).pop(c.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (key == null) return;
    final id = await installer.install(key);
    if (context.mounted) context.go(Routes.folder(id));
  }
}

/// Große Kachel für einen Kursordner (Lehrbuch oder Niveau).
class CourseFolderTile extends StatelessWidget {
  const CourseFolderTile({super.key, required this.item});

  final FolderWithCount item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = item.folder;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('course_${f.courseKey}'),
        onTap: () => context.go(Routes.folder(f.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              LanguageBadge(code: f.language ?? ''),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${item.setCount} Sets · ${item.cardCount} Karten',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sprachkürzel bzw. Flagge im farbigen Kreis.
class LanguageBadge extends StatelessWidget {
  const LanguageBadge({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = code == 'tr'
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer)
        : (scheme.primaryContainer, scheme.onPrimaryContainer);
    return CircleAvatar(
      radius: 22,
      backgroundColor: bg,
      foregroundColor: fg,
      child: Text(
        StudyLanguage.fromCode(code)?.flag ?? code.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
