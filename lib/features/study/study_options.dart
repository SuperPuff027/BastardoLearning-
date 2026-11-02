import 'package:flutter/material.dart';

import '../../core/learning/test_generator.dart';
import '../settings/app_settings.dart';

enum StudyModeKind {
  flashcards('Karteikarten', Icons.style_outlined, 'karteikarten'),
  learn('Lernmodus', Icons.auto_graph_outlined, 'lernmodus'),
  write('Schreiben', Icons.keyboard_outlined, 'schreiben'),
  test('Test', Icons.quiz_outlined, 'test');

  const StudyModeKind(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

/// Einstellungen für eine Lernsitzung, als Query-Parameter übertragbar.
@immutable
class StudyOptions {
  const StudyOptions({
    this.direction = QuizDirection.mixed,
    this.starredOnly = false,
    this.shuffle = true,
    this.questionCount = 10,
    this.testTypes = const {
      TestQuestionType.multipleChoice,
      TestQuestionType.trueFalse,
      TestQuestionType.written,
      TestQuestionType.matching,
    },
  });

  final QuizDirection direction;
  final bool starredOnly;
  final bool shuffle;
  final int questionCount;
  final Set<TestQuestionType> testTypes;

  StudyOptions copyWith({
    QuizDirection? direction,
    bool? starredOnly,
    bool? shuffle,
    int? questionCount,
    Set<TestQuestionType>? testTypes,
  }) => StudyOptions(
    direction: direction ?? this.direction,
    starredOnly: starredOnly ?? this.starredOnly,
    shuffle: shuffle ?? this.shuffle,
    questionCount: questionCount ?? this.questionCount,
    testTypes: testTypes ?? this.testTypes,
  );

  static const _typeCodes = {
    TestQuestionType.multipleChoice: 'mc',
    TestQuestionType.trueFalse: 'wf',
    TestQuestionType.written: 'text',
    TestQuestionType.matching: 'zuordnen',
  };

  Map<String, String> toQuery() => {
    'richtung': direction.storageValue,
    if (starredOnly) 'markiert': '1',
    'mischen': shuffle ? '1' : '0',
    'anzahl': '$questionCount',
    'typen': [for (final t in testTypes) _typeCodes[t]].join(','),
  };

  factory StudyOptions.fromQuery(Map<String, String> q) {
    const d = StudyOptions();
    final types = {
      for (final code in (q['typen'] ?? '').split(','))
        for (final e in _typeCodes.entries)
          if (e.value == code) e.key,
    };
    return StudyOptions(
      direction: QuizDirection.fromStorage(q['richtung']),
      starredOnly: q['markiert'] == '1',
      shuffle: q['mischen'] != '0',
      questionCount: int.tryParse(q['anzahl'] ?? '') ?? d.questionCount,
      testTypes: types.isEmpty ? d.testTypes : types,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StudyOptions &&
      other.direction == direction &&
      other.starredOnly == starredOnly &&
      other.shuffle == shuffle &&
      other.questionCount == questionCount &&
      other.testTypes.length == testTypes.length &&
      other.testTypes.containsAll(testTypes);

  @override
  int get hashCode => Object.hash(
    direction,
    starredOnly,
    shuffle,
    questionCount,
    Object.hashAllUnordered(testTypes),
  );
}

/// Blatt mit den Optionen vor dem Start eines Lernmodus.
/// Gibt `null` zurück, wenn abgebrochen wurde.
Future<StudyOptions?> showStudyOptionsSheet(
  BuildContext context, {
  required StudyModeKind mode,
  required StudyOptions initial,
  required int cardCount,
  required int starredCount,
}) {
  return showModalBottomSheet<StudyOptions>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OptionsSheet(
      mode: mode,
      initial: initial,
      cardCount: cardCount,
      starredCount: starredCount,
    ),
  );
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({
    required this.mode,
    required this.initial,
    required this.cardCount,
    required this.starredCount,
  });

  final StudyModeKind mode;
  final StudyOptions initial;
  final int cardCount;
  final int starredCount;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late StudyOptions _o = widget.initial.copyWith(
    questionCount: widget.initial.questionCount.clamp(1, widget.cardCount),
  );

  int get _available => _o.starredOnly ? widget.starredCount : widget.cardCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTest = widget.mode == StudyModeKind.test;
    final maxCount = _available < 1 ? 1 : _available;
    final count = _o.questionCount.clamp(1, maxCount);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.mode.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Abfragerichtung', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<QuizDirection>(
              key: const Key('optionDirection'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: QuizDirection.mixed,
                  label: Text('Gemischt'),
                ),
                ButtonSegment(
                  value: QuizDirection.foreignToGerman,
                  label: Text('Fremd → DE'),
                ),
                ButtonSegment(
                  value: QuizDirection.germanToForeign,
                  label: Text('DE → Fremd'),
                ),
              ],
              selected: {_o.direction},
              onSelectionChanged: (s) =>
                  setState(() => _o = _o.copyWith(direction: s.first)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('optionStarred'),
              contentPadding: EdgeInsets.zero,
              title: Text('Nur markierte Karten (${widget.starredCount})'),
              value: _o.starredOnly,
              onChanged: widget.starredCount == 0
                  ? null
                  : (v) => setState(() => _o = _o.copyWith(starredOnly: v)),
            ),
            if (widget.mode == StudyModeKind.flashcards ||
                widget.mode == StudyModeKind.write)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mischen'),
                value: _o.shuffle,
                onChanged: (v) => setState(() => _o = _o.copyWith(shuffle: v)),
              ),
            if (isTest) ...[
              const SizedBox(height: 8),
              Text(
                'Anzahl Fragen: $count von $_available',
                style: theme.textTheme.titleSmall,
              ),
              if (maxCount > 1)
                Slider(
                  value: count.toDouble(),
                  min: 1,
                  max: maxCount.toDouble(),
                  divisions: maxCount - 1,
                  label: '$count',
                  onChanged: (v) => setState(
                    () => _o = _o.copyWith(questionCount: v.round()),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Fragetypen', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in TestQuestionType.values)
                    FilterChip(
                      label: Text(t.label),
                      selected: _o.testTypes.contains(t),
                      onSelected: (v) {
                        final types = {..._o.testTypes};
                        v ? types.add(t) : types.remove(t);
                        if (types.isNotEmpty) {
                          setState(() => _o = _o.copyWith(testTypes: types));
                        }
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('startStudy'),
              onPressed: _available == 0
                  ? null
                  : () =>
                        Navigator.of(context)
                            .pop(_o.copyWith(questionCount: count)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Starten'),
            ),
          ],
        ),
      ),
    );
  }
}
