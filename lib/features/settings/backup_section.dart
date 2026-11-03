import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/backup.dart';

/// Daten sichern und wiederherstellen (eine JSON-Datei).
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(backupServiceProvider).export();
      final d = DateTime.now();
      final name =
          'barstardo-sicherung-${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
      final saved = await ref.read(backupFileIoProvider).save(name, bytes);
      if (saved) _message('Sicherung gespeichert: $name');
    } catch (e) {
      _message('Export fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final bytes = await ref.read(backupFileIoProvider).open();
    if (bytes == null || !mounted) return;
    final service = ref.read(backupServiceProvider);
    final BackupSummary summary;
    try {
      summary = service.inspect(bytes);
    } on BackupException catch (e) {
      _message(e.message);
      return;
    }
    final created = summary.createdAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sicherung wiederherstellen?'),
        content: Text(
          'Die Sicherung${created == null ? '' : ' vom ${created.day}.${created.month}.${created.year}'} '
          'enthält ${summary.sets} Sets und ${summary.cards} Karten.\n\n'
          'Alle aktuellen Daten in der App werden dadurch ersetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('confirmRestore'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ersetzen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final result = await service.restore(bytes);
      await ref.read(settingsProvider.notifier).reload();
      _message(
        'Wiederhergestellt: ${result.sets} Sets, ${result.cards} Karten',
      );
    } on BackupException catch (e) {
      _message(e.message);
    } catch (e) {
      _message('Wiederherstellen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            kIsWeb
                ? 'Im Browser können Daten verloren gehen, z. B. wenn Safari '
                      'Website-Daten löscht. Sichere regelmäßig – etwa in '
                      'iCloud Drive („In Dateien sichern“).'
                : 'Deine Daten liegen nur auf diesem Gerät. Mit einer Sicherung '
                      'kannst du sie auf ein neues Handy mitnehmen.',
          ),
        ),
        ListTile(
          key: const Key('exportBackup'),
          enabled: !_busy,
          leading: const Icon(Icons.save_alt),
          title: const Text('Sicherung exportieren'),
          subtitle: const Text('Alle Sets, Karten, Lernfortschritt und Bilder'),
          onTap: _export,
        ),
        ListTile(
          key: const Key('importBackup'),
          enabled: !_busy,
          leading: const Icon(Icons.restore),
          title: const Text('Sicherung importieren'),
          subtitle: const Text('Ersetzt die aktuellen Daten'),
          trailing: _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _import,
        ),
      ],
    );
  }
}
