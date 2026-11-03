import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'app_settings.dart';
import 'backup_section.dart';
import 'offline_translation_section.dart';
import '../scan/scan_services.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const _SectionHeader('Darstellung'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              key: const Key('themeModeSelector'),
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Hell'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dunkel'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.setThemeMode(s.first),
            ),
          ),
          const _SectionHeader('Lernen'),
          ListTile(
            title: const Text('Abfragerichtung'),
            subtitle: Text(settings.quizDirection.label),
            trailing: DropdownButton<QuizDirection>(
              key: const Key('quizDirectionSelector'),
              value: settings.quizDirection,
              underline: const SizedBox.shrink(),
              items: [
                for (final d in QuizDirection.values)
                  DropdownMenuItem(value: d, child: Text(d.label)),
              ],
              onChanged: (d) {
                if (d != null) notifier.setQuizDirection(d);
              },
            ),
          ),
          SwitchListTile(
            key: const Key('ttsSwitch'),
            title: const Text('Vorlesen (Text-to-Speech)'),
            subtitle: const Text(
              'Global aus: Es wird nie vorgelesen, auch wenn ein Set es erlaubt.',
            ),
            value: settings.ttsEnabled,
            onChanged: notifier.setTtsEnabled,
          ),
          const _SectionHeader('Erinnerungen'),
          SwitchListTile(
            key: const Key('remindersSwitch'),
            title: const Text('Tägliche Erinnerung'),
            subtitle: const Text('Lokale Benachrichtigung, ohne Internet'),
            value: settings.remindersEnabled,
            onChanged: notifier.setRemindersEnabled,
          ),
          ListTile(
            key: const Key('reminderTimeTile'),
            enabled: settings.remindersEnabled,
            title: const Text('Uhrzeit'),
            trailing: Text(
              '${AppSettings.formatTime(settings.reminderTime)} Uhr',
              style: textTheme.bodyLarge,
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: settings.reminderTime,
                helpText: 'Erinnerung um',
              );
              if (picked != null) await notifier.setReminderTime(picked);
            },
          ),
          if (ref.watch(onDeviceMlAvailableProvider)) ...[
            const _SectionHeader('Offline-Übersetzung'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Für Wörter, die nicht in der Vokabeldatenbank stehen (z. B. beim Foto-Import). Optional.',
              ),
            ),
            const OfflineTranslationSection(),
          ],
          const _SectionHeader('Daten sichern'),
          const BackupSection(),
          const _SectionHeader('Datenschutz'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Alle Daten bleiben auf diesem Gerät'),
            subtitle: Text(
              'Kein Account, keine Cloud, keine Analytics. Ohne Sicherung gehen die Daten beim Löschen der App verloren.',
            ),
          ),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: 'Barstardo Learning',
            applicationLegalese:
                'Offline-Vokabeltrainer für Spanisch und Türkisch',
            aboutBoxChildren: [
              const SizedBox(height: 16),
              Text('Vokabeldatenbank', style: textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(ref.read(vocabRepositoryProvider).attribution),
            ],
            child: const Text('Über die App & Lizenzen'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
