import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/study_language.dart';
import '../../data/library_repository.dart';

/// Zeigt den Inhalt eines AsyncValue oder Lade-/Fehlerzustand.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) => switch (value) {
    AsyncData(:final value) => data(value),
    AsyncError(:final error) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Fehler beim Laden: $error', textAlign: TextAlign.center),
      ),
    ),
    _ => const Center(child: CircularProgressIndicator()),
  };
}

class SetTile extends StatelessWidget {
  const SetTile({super.key, required this.item, required this.onTap});

  final SetWithCount item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = StudyLanguage.fromCode(item.set.language);
    final count = item.cardCount;
    return ListTile(
      leading: CircleAvatar(child: Text(lang?.flag ?? item.set.language)),
      title: Text(item.set.title),
      subtitle: Text(
        '$count ${count == 1 ? 'Karte' : 'Karten'} · ${StudyLanguage.labelFor(item.set.language)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Vorschaubild einer Karte aus der lokalen Medienablage.
class CardImage extends ConsumerWidget {
  const CardImage({
    super.key,
    required this.path,
    this.size,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double? size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(mediaStoreProvider).resolve(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

/// Fragt einen Namen ab (z. B. für Ordner). Gibt `null` bei Abbruch zurück.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String label = 'Name',
  String confirm = 'Speichern',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        final text = controller.text.trim();
        if (text.isNotEmpty) Navigator.of(context).pop(text);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('nameDialogField'),
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(onPressed: submit, child: Text(confirm)),
        ],
      );
    },
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Löschen',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
