import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/placeholder_view.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../data/database.dart';
import 'library_providers.dart';
import 'widgets.dart';

class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key, required this.folderId});

  final int folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref.watch(folderProvider(folderId));
    final sets = ref.watch(setsInFolderProvider(folderId));

    return AsyncBody(
      value: folder,
      data: (f) {
        if (f == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const PlaceholderView(
              icon: Icons.folder_off_outlined,
              title: 'Ordner nicht gefunden',
              message: 'Dieser Ordner wurde gelöscht.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(f.name),
            actions: [
              PopupMenuButton<String>(
                key: const Key('folderMenu'),
                onSelected: (v) => switch (v) {
                  'rename' => _rename(context, ref, f),
                  'delete' => _delete(context, ref, f),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                  PopupMenuItem(value: 'delete', child: Text('Ordner löschen')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go(Routes.newSet(folderId: folderId)),
            icon: const Icon(Icons.add),
            label: const Text('Neues Set'),
          ),
          body: AsyncBody(
            value: sets,
            data: (list) => list.isEmpty
                ? const PlaceholderView(
                    icon: Icons.folder_open_outlined,
                    title: 'Ordner ist leer',
                    message: 'Lege hier ein neues Set an oder verschiebe ein bestehendes Set in diesen Ordner.',
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      for (final s in list)
                        SetTile(
                          item: s,
                          onTap: () => context.go(Routes.set(s.set.id)),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Folder f) async {
    final name = await showNameDialog(
      context,
      title: 'Ordner umbenennen',
      initial: f.name,
    );
    if (name != null) {
      await ref.read(libraryRepositoryProvider).renameFolder(f.id, name);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Folder f) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${f.name}“ löschen?'),
        content: const Text(
          'Die Sets in diesem Ordner kannst du behalten oder mitlöschen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('all'),
            child: const Text('Mit Sets löschen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('folder'),
            child: const Text('Sets behalten'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    context.go(Routes.library);
    await ref
        .read(libraryRepositoryProvider)
        .deleteFolder(f.id, deleteSets: choice == 'all');
  }
}
