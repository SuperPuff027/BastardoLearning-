import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/placeholder_view.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../data/library_repository.dart';
import 'library_providers.dart';
import 'widgets.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);
    final sets = ref.watch(setsInFolderProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Meine Sets')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('libraryAdd'),
        onPressed: () => _showCreateSheet(context, ref),
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
                message: 'Lege mit „Neu“ dein erstes Set oder einen Ordner an.',
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (folderList.isNotEmpty) ...[
                  const SectionHeader('Ordner'),
                  for (final f in folderList)
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

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('Neues Set'),
              onTap: () => Navigator.of(context).pop('set'),
            ),
            ListTile(
              key: const Key('createPreset'),
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('Vorgefertigtes Set'),
              subtitle: const Text(
                'Aus der Vokabeldatenbank nach Niveau und Thema',
              ),
              onTap: () => Navigator.of(context).pop('preset'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Neuer Ordner'),
              onTap: () => Navigator.of(context).pop('folder'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'set':
        context.go(Routes.newSet());
      case 'preset':
        context.go(Routes.presets);
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
}
