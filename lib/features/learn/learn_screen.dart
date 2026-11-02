import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/placeholder_view.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/study_language.dart';
import '../../data/study_repository.dart';
import '../library/widgets.dart';

final dueSummaryProvider = StreamProvider.autoDispose<List<DueSummary>>(
  (ref) => ref.watch(studyRepositoryProvider).watchDueSummary(),
);

/// Tab „Lernen“: fällige Wiederholungen (Spaced Repetition) pro Set.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dueSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lernen')),
      body: AsyncBody(
        value: summary,
        data: (list) {
          final withCards = list.where((s) => s.due + s.fresh > 0).toList();
          if (withCards.isEmpty) {
            return const PlaceholderView(
              icon: Icons.school_outlined,
              title: 'Nichts fällig',
              message: 'Sobald du Sets mit Karten hast, findest du hier deine fälligen Karten.',
            );
          }
          final totalDue = list.fold(0, (s, x) => s + x.due);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dueSummaryProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          totalDue == 0
                              ? 'Keine Wiederholungen fällig'
                              : '$totalDue ${totalDue == 1 ? 'Karte' : 'Karten'} fällig',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Spaced Repetition: Karten kommen genau dann wieder, wenn du sie sonst vergessen würdest.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('reviewAll'),
                          onPressed: () async {
                            await context.push(Routes.review());
                            ref.invalidate(dueSummaryProvider);
                          },
                          icon: const Icon(Icons.replay),
                          label: Text(
                            totalDue == 0
                                ? 'Neue Karten lernen'
                                : 'Alle fälligen wiederholen',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionHeader('Nach Set'),
                for (final s in withCards)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        StudyLanguage.fromCode(s.set.language)?.flag ?? '',
                      ),
                    ),
                    title: Text(s.set.title),
                    subtitle: Text('${s.due} fällig · ${s.fresh} neu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push(Routes.review(setId: s.set.id));
                      ref.invalidate(dueSummaryProvider);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
