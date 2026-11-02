import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/study_language.dart';
import '../scan/scan_services.dart';

/// Optionale Sprachmodelle für die Übersetzung auf dem Gerät.
/// Einmaliger Download (erlaubte Ausnahme von „offline-first“), danach offline.
class OfflineTranslationSection extends ConsumerStatefulWidget {
  const OfflineTranslationSection({super.key});

  @override
  ConsumerState<OfflineTranslationSection> createState() =>
      _OfflineTranslationSectionState();
}

class _OfflineTranslationSectionState
    extends ConsumerState<OfflineTranslationSection> {
  final _ready = <StudyLanguage, bool?>{};
  final _busy = <StudyLanguage>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = ref.read(translationProvider);
    for (final l in StudyLanguage.values) {
      bool? ready;
      try {
        ready = await service.isReady(l.code);
      } catch (_) {
        ready = null; // auf diesem Gerät nicht verfügbar
      }
      if (!mounted) return;
      setState(() => _ready[l] = ready);
    }
  }

  Future<void> _download(StudyLanguage l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l.label}-Modell laden?'),
        content: const Text(
          'Für die Übersetzung auf dem Gerät werden einmalig Sprachmodelle '
          'geladen (ca. 30 MB pro Sprache, plus Deutsch). Danach funktioniert '
          'die Übersetzung ohne Internet. Der Download startet nur im WLAN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Laden'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy.add(l));
    try {
      final done = await ref.read(translationProvider).download(l.code);
      if (!done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download nicht möglich – bist du im WLAN?'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download fehlgeschlagen: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(l));
      await _refresh();
    }
  }

  Future<void> _delete(StudyLanguage l) async {
    setState(() => _busy.add(l));
    try {
      await ref.read(translationProvider).delete(l.code);
    } catch (_) {
      // ignorieren
    } finally {
      if (mounted) setState(() => _busy.remove(l));
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final l in StudyLanguage.values)
          ListTile(
            key: Key('translationModel-${l.code}'),
            leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
            title: Text('${l.label} → Deutsch'),
            subtitle: Text(switch (_ready[l]) {
              true => 'Geladen – übersetzt offline',
              false => 'Nicht geladen',
              null => 'Auf diesem Gerät nicht verfügbar',
            }),
            trailing: _busy.contains(l)
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : switch (_ready[l]) {
                    true => IconButton(
                      tooltip: 'Modell löschen',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(l),
                    ),
                    false => IconButton(
                      tooltip: 'Modell laden',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () => _download(l),
                    ),
                    null => null,
                  },
          ),
      ],
    );
  }
}
