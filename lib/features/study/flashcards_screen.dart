import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/learning/flashcard_session.dart';
import '../../core/learning/fsrs.dart';
import '../../core/learning/study_item.dart';
import '../../data/study_repository.dart';
import 'session_base.dart';
import 'study_options.dart';
import 'study_widgets.dart';

/// Karteikarten (Brief Nr. 11): umdrehen, wischen, mischen.
class FlashcardsScreen extends ConsumerStatefulWidget {
  const FlashcardsScreen({
    super.key,
    required this.setId,
    required this.options,
  });

  final int setId;
  final StudyOptions options;

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen>
    with StudySessionLoader {
  @override
  int get setId => widget.setId;
  @override
  StudyOptions get options => widget.options;

  FlashcardSession? _session;
  bool _flipped = false;
  final _watch = Stopwatch();

  @override
  void initState() {
    super.initState();
    loadStudy();
  }

  @override
  void onLoaded(List<StudyCard> cards) {
    setState(() {
      _session = FlashcardSession(
        cards,
        directions: directionPicker,
        shuffle: options.shuffle,
        random: ref.read(randomProvider),
      );
    });
    _watch.start();
  }

  void _answer(bool knewIt) {
    final s = _session!;
    if (s.isFinished) return;
    final card = s.current;
    final ms = _watch.elapsedMilliseconds;
    setState(() {
      s.answer(knewIt: knewIt);
      _flipped = false;
    });
    _watch
      ..reset()
      ..start();
    recordAnswer(
      card.id,
      StudyMode.flashcards,
      knewIt ? Rating.good : Rating.again,
      responseMs: ms,
    );
  }

  void _undo() {
    setState(() {
      _session!.undo();
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s == null || s.isFinished
              ? 'Karteikarten'
              : 'Karte ${s.position + 1} von ${s.total}',
        ),
        bottom: s == null
            ? null
            : progressBar(s.total == 0 ? 1 : s.position / s.total),
        actions: [
          if (s != null && !s.isFinished && s.position > 0)
            IconButton(
              tooltip: 'Rückgängig',
              onPressed: _undo,
              icon: const Icon(Icons.undo),
            ),
        ],
      ),
      body: SafeArea(child: _body(s)),
    );
  }

  Widget _body(FlashcardSession? s) {
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (s.total == 0) {
      return const StudyEmpty(message: 'Keine Karten zum Lernen.');
    }
    if (s.isFinished) {
      final unknown = s.unknown.length;
      return SessionSummary(
        title: 'Runde geschafft!',
        lines: ['Gewusst: ${s.known.length}', 'Nicht gewusst: $unknown'],
        retryLabel: unknown == 0
            ? null
            : 'Nicht gewusste wiederholen ($unknown)',
        onRetry: unknown == 0
            ? null
            : () => setState(() {
                _session = s.retryUnknown(shuffle: options.shuffle);
                _flipped = false;
              }),
        onDone: () => context.pop(),
      );
    }
    final card = s.current;
    final foreignFirst = s.direction == AskDirection.foreignToGerman;
    final showForeign = foreignFirst != _flipped;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              key: const Key('flashcard'),
              onTap: () => setState(() => _flipped = !_flipped),
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 200) return;
                _answer(v > 0);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => AnimatedBuilder(
                  animation: anim,
                  child: child,
                  builder: (context, child) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY((1 - anim.value) * pi / 2),
                    child: child,
                  ),
                ),
                child: Card(
                  key: ValueKey('${card.id}-$_flipped'),
                  child: SizedBox.expand(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: SingleChildScrollView(
                          child: CardSideView(
                            card: card,
                            foreignSide: showForeign,
                            label: showForeign ? languageLabel : 'Deutsch',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tippen zum Umdrehen · nach links wischen: nicht gewusst, nach rechts: gewusst',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('unknownButton'),
                  onPressed: () => _answer(false),
                  icon: const Icon(Icons.close),
                  label: const Text('Nicht gewusst'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('knownButton'),
                  onPressed: () => _answer(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Gewusst'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
