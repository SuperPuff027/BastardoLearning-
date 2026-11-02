import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/learning/fsrs.dart';
import '../../core/learning/study_item.dart';
import '../../core/learning/test_generator.dart';
import '../../data/study_repository.dart';
import 'session_base.dart';
import 'study_options.dart';
import 'study_widgets.dart';

/// Test (Brief Nr. 15): Multiple Choice, Wahr/Falsch, Freitext, Zuordnen.
class TestScreen extends ConsumerStatefulWidget {
  const TestScreen({super.key, required this.setId, required this.options});

  final int setId;
  final StudyOptions options;

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen>
    with StudySessionLoader {
  @override
  int get setId => widget.setId;
  @override
  StudyOptions get options => widget.options;

  List<TestQuestion>? _questions;
  bool _submitted = false;
  final _controllers = <WrittenQuestion, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    loadStudy();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void onLoaded(List<StudyCard> cards) {
    final qs =
        TestGenerator(
          directions: directionPicker,
          random: ref.read(randomProvider),
        ).generate(
          cards,
          TestConfig(
            questionCount: options.questionCount,
            types: options.testTypes,
          ),
        );
    setState(() => _questions = qs);
  }

  TextEditingController _controllerFor(WrittenQuestion q) =>
      _controllers.putIfAbsent(q, () => TextEditingController(text: q.text));

  Future<void> _submit() async {
    final qs = _questions!;
    final open = qs.where((q) => !q.isAnswered).length;
    if (open > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Test abgeben?'),
          content: Text(
            '$open ${open == 1 ? 'Frage ist' : 'Fragen sind'} noch unbeantwortet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Weiter bearbeiten'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Abgeben'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _submitted = true);
    for (final q in qs) {
      for (final (cardId, ok) in _cardResults(q)) {
        await recordAnswer(
          cardId,
          StudyMode.test,
          ok ? Rating.good : Rating.again,
          correct: ok,
        );
      }
    }
  }

  Iterable<(int, bool)> _cardResults(TestQuestion q) => switch (q) {
    MultipleChoiceQuestion() => [(q.card.id, q.points == 1)],
    TrueFalseQuestion() => [(q.card.id, q.points == 1)],
    WrittenQuestion() => [(q.card.id, q.points == 1)],
    MatchingQuestion() => [
      for (final c in q.cards)
        (c.id, q.selections[c.id] == c.answerFor(q.direction)),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final qs = _questions;
    final answered = qs?.where((q) => q.isAnswered).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_submitted ? 'Ergebnis' : 'Test'),
        bottom: qs == null || _submitted || qs.isEmpty
            ? null
            : progressBar(answered / qs.length),
      ),
      bottomNavigationBar: qs == null || qs.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _submitted
                    ? OutlinedButton(
                        key: const Key('doneButton'),
                        onPressed: () => context.pop(),
                        child: const Text('Fertig'),
                      )
                    : FilledButton(
                        key: const Key('submitTest'),
                        onPressed: _submit,
                        child: Text('Abgeben ($answered/${qs.length})'),
                      ),
              ),
            ),
      body: _body(qs),
    );
  }

  Widget _body(List<TestQuestion>? qs) {
    if (qs == null) return const Center(child: CircularProgressIndicator());
    if (qs.isEmpty) {
      return const StudyEmpty(message: 'Keine Karten für einen Test.');
    }
    final score = TestScore.of(qs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_submitted)
          Card(
            key: const Key('testScore'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${score.percent} %',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  Text('${score.points} von ${score.maxPoints} Punkten'),
                ],
              ),
            ),
          ),
        for (var i = 0; i < qs.length; i++) ...[
          const SizedBox(height: 12),
          _QuestionCard(
            index: i,
            question: qs[i],
            submitted: _submitted,
            languageLabel: languageLabel,
            answerLanguage: answerLanguage(qs[i].direction),
            controllerFor: _controllerFor,
            onChanged: () => setState(() {}),
          ),
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.submitted,
    required this.languageLabel,
    required this.answerLanguage,
    required this.controllerFor,
    required this.onChanged,
  });

  final int index;
  final TestQuestion question;
  final bool submitted;
  final String languageLabel;
  final String answerLanguage;
  final TextEditingController Function(WrittenQuestion) controllerFor;
  final VoidCallback onChanged;

  String _dirLabel(AskDirection d) => d == AskDirection.foreignToGerman
      ? '$languageLabel → Deutsch'
      : 'Deutsch → $languageLabel';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;
    final correct = q.points == q.maxPoints;
    return Card(
      key: Key('question-$index'),
      shape: submitted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: correct ? Colors.green : theme.colorScheme.error,
                width: 2,
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Frage ${index + 1} · ${_typeLabel(q)} · ${_dirLabel(q.direction)}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            ..._content(context, q),
          ],
        ),
      ),
    );
  }

  String _typeLabel(TestQuestion q) => switch (q) {
    MultipleChoiceQuestion() => TestQuestionType.multipleChoice.label,
    TrueFalseQuestion() => TestQuestionType.trueFalse.label,
    WrittenQuestion() => TestQuestionType.written.label,
    MatchingQuestion() => TestQuestionType.matching.label,
  };

  List<Widget> _content(BuildContext context, TestQuestion q) {
    final theme = Theme.of(context);
    final prompt = theme.textTheme.titleLarge;
    switch (q) {
      case MultipleChoiceQuestion():
        return [
          Text(q.card.promptFor(q.direction), style: prompt),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: q.selected,
            onChanged: (v) {
              if (submitted) return;
              q.selected = v;
              onChanged();
            },
            child: Column(
              children: [
                for (final c in q.choices)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: c,
                    title: Text(c),
                    secondary: submitted
                        ? _mark(c == q.expected, c == q.selected)
                        : null,
                  ),
              ],
            ),
          ),
        ];
      case TrueFalseQuestion():
        return [
          Text(q.card.promptFor(q.direction), style: prompt),
          const SizedBox(height: 4),
          Text('= ${q.shownAnswer}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: true, label: Text('Wahr')),
              ButtonSegment(value: false, label: Text('Falsch')),
            ],
            selected: {if (q.selected != null) q.selected!},
            onSelectionChanged: submitted
                ? null
                : (s) {
                    q.selected = s.isEmpty ? null : s.first;
                    onChanged();
                  },
          ),
          if (submitted && q.points == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Richtig wäre: ${q.isTrue ? 'Wahr' : 'Falsch'} – ${q.card.promptFor(q.direction)} = ${q.card.answerFor(q.direction)}',
              ),
            ),
        ];
      case WrittenQuestion():
        final controller = controllerFor(q);
        return [
          Text(q.card.promptFor(q.direction), style: prompt),
          const SizedBox(height: 8),
          if (!submitted) ...[
            TextField(
              controller: controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Antwort',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                q.text = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            SpecialCharsBar(language: answerLanguage, controller: controller),
          ] else
            AnswerFeedback(
              accepted: q.points == 1 && !q.overridden,
              expected: q.expected,
              given: q.text,
              grade: q.grade,
              overridden: q.overridden,
              onOverride: () {
                q.overridden = true;
                onChanged();
              },
            ),
        ];
      case MatchingQuestion():
        return [
          const Text('Ordne die passenden Antworten zu.'),
          const SizedBox(height: 8),
          for (final c in q.cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.promptFor(q.direction),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('wählen'),
                      value: q.selections[c.id],
                      items: [
                        for (final a in q.answerOptions)
                          DropdownMenuItem(value: a, child: Text(a)),
                      ],
                      onChanged: submitted
                          ? null
                          : (v) {
                              if (v != null) q.selections[c.id] = v;
                              onChanged();
                            },
                    ),
                  ),
                  if (submitted)
                    _mark(q.selections[c.id] == c.answerFor(q.direction), true),
                ],
              ),
            ),
          if (submitted)
            for (final c in q.cards)
              if (q.selections[c.id] != c.answerFor(q.direction))
                Text(
                  '${c.promptFor(q.direction)} = ${c.answerFor(q.direction)}',
                  style: theme.textTheme.bodySmall,
                ),
        ];
    }
  }

  Widget _mark(bool isCorrect, bool isSelected) {
    if (isCorrect) return const Icon(Icons.check, color: Colors.green);
    if (isSelected) return const Icon(Icons.close, color: Colors.red);
    return const SizedBox(width: 24);
  }
}
