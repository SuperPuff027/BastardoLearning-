import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/learning/fsrs.dart';
import '../../core/learning/study_item.dart';
import '../../core/study_language.dart';
import '../../data/study_repository.dart';
import 'study_widgets.dart';

/// Spaced Repetition mit FSRS (Brief Nr. 16): fällige und neue Karten,
/// Selbsteinschätzung Nochmal / Schwer / Gut / Leicht.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.setId});

  /// `null` = fällige Karten aus allen Sets.
  final int? setId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<ReviewItem>? _queue;
  final _languages = <int, String>{};
  late DirectionPicker _directions;
  AskDirection _direction = AskDirection.foreignToGerman;
  bool _revealed = false;
  int _done = 0;
  final _counts = {for (final r in Rating.values) r: 0};
  final _watch = Stopwatch();

  StudyRepository get _repo => ref.read(studyRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _directions = DirectionPicker(
      ref.read(settingsProvider).quizDirection,
      ref.read(randomProvider),
    );
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.dueItems(setId: widget.setId);
    // Sprache pro Karte für die Beschriftung
    final library = ref.read(libraryRepositoryProvider);
    final sets = await library.getAllSets();
    final langBySet = {for (final s in sets) s.set.id: s.set.language};
    final setOfCard = await library.setIdsOfCards(items.map((i) => i.card.id));
    for (final e in setOfCard.entries) {
      _languages[e.key] = langBySet[e.value] ?? '';
    }
    if (!mounted) return;
    setState(() {
      _queue = items;
      _direction = _directions.next();
    });
    _watch.start();
  }

  bool _busy = false;

  Future<void> _rate(Rating rating) async {
    if (_busy) return; // Doppeltipp nicht doppelt speichern
    _busy = true;
    final q = _queue!;
    final item = q.first;
    final ms = _watch.elapsedMilliseconds;
    final memory = await _repo.record(
      cardId: item.card.id,
      mode: StudyMode.review,
      rating: rating,
      responseMs: ms,
    );
    _busy = false;
    if (!mounted) return;
    setState(() {
      q.removeAt(0);
      _counts[rating] = _counts[rating]! + 1;
      if (rating == Rating.again) {
        // Kommt in dieser Sitzung noch einmal dran.
        q.add(ReviewItem(item.card, memory));
      } else {
        _done++;
      }
      _revealed = false;
      _direction = _directions.next();
    });
    _watch
      ..reset()
      ..start();
  }

  @override
  Widget build(BuildContext context) {
    final q = _queue;
    final total = q == null ? 0 : q.length + _done;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          q == null || q.isEmpty
              ? 'Wiederholen'
              : 'Noch ${q.length} ${q.length == 1 ? 'Karte' : 'Karten'}',
        ),
        bottom: q == null ? null : progressBar(total == 0 ? 1 : _done / total),
      ),
      body: SafeArea(child: _body(q)),
    );
  }

  Widget _body(List<ReviewItem>? q) {
    if (q == null) return const Center(child: CircularProgressIndicator());
    if (q.isEmpty) {
      if (_done == 0 && _counts[Rating.again] == 0) {
        return SessionSummary(
          title: 'Nichts fällig',
          lines: const ['Alle Karten sind auf dem neuesten Stand.'],
          onDone: () => context.pop(),
        );
      }
      return SessionSummary(
        title: 'Wiederholung abgeschlossen',
        lines: [
          '$_done ${_done == 1 ? 'Karte' : 'Karten'} wiederholt',
          for (final r in Rating.values)
            if (_counts[r]! > 0) '${r.label}: ${_counts[r]}',
        ],
        onDone: () => context.pop(),
      );
    }
    final item = q.first;
    final card = item.card;
    final languageLabel = StudyLanguage.labelFor(_languages[card.id] ?? '');
    final preview = ref
        .read(studyRepositoryProvider)
        .fsrs
        .preview(item.memory, _repo.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.memory == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Chip(label: Text('Neue Karte')),
          ),
        PromptCard(
          card: card,
          direction: _direction,
          languageLabel: languageLabel,
        ),
        const SizedBox(height: 16),
        if (!_revealed)
          FilledButton(
            key: const Key('revealAnswer'),
            onPressed: () => setState(() => _revealed = true),
            child: const Text('Antwort zeigen'),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CardSideView(
                  card: card,
                  foreignSide: _direction == AskDirection.germanToForeign,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Wie gut wusstest du es?',
            style: Theme.of(context).textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final r in Rating.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _RatingButton(
                      rating: r,
                      interval: formatInterval(preview[r]!),
                      onPressed: () => _rate(r),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.interval,
    required this.onPressed,
  });

  final Rating rating;
  final String interval;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = switch (rating) {
      Rating.again => Colors.red,
      Rating.hard => Colors.orange,
      Rating.good => Colors.green,
      Rating.easy => Colors.blue,
    };
    return OutlinedButton(
      key: Key('rate-${rating.name}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
          Text(interval, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
