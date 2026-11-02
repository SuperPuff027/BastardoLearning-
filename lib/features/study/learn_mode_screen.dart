import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/learning/fsrs.dart';
import '../../core/learning/learn_session.dart';
import '../../core/learning/study_item.dart';
import '../../data/study_repository.dart';
import 'session_base.dart';
import 'study_options.dart';
import 'study_widgets.dart';

/// Adaptiver Lernmodus (Brief Nr. 12).
class LearnModeScreen extends ConsumerStatefulWidget {
  const LearnModeScreen({
    super.key,
    required this.setId,
    required this.options,
  });

  final int setId;
  final StudyOptions options;

  @override
  ConsumerState<LearnModeScreen> createState() => _LearnModeScreenState();
}

class _LearnModeScreenState extends ConsumerState<LearnModeScreen>
    with StudySessionLoader {
  @override
  int get setId => widget.setId;
  @override
  StudyOptions get options => widget.options;

  LearnSession? _session;
  LearnOutcome? _outcome;
  String? _given;
  bool _overridden = false;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _watch = Stopwatch();
  int _responseMs = 0;

  @override
  void initState() {
    super.initState();
    loadStudy();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Future<void> onLoaded(List<StudyCard> cards) async {
    final errors = await ref
        .read(studyRepositoryProvider)
        .pastErrors(cards.map((c) => c.id));
    if (!mounted) return;
    setState(() {
      _session = LearnSession(
        cards,
        directions: directionPicker,
        pastErrors: errors,
        random: ref.read(randomProvider),
      );
    });
    _watch.start();
  }

  void _answerChoice(String choice) {
    if (_outcome != null) return;
    _responseMs = _watch.elapsedMilliseconds;
    setState(() {
      _given = choice;
      _outcome = _session!.answerChoice(choice);
    });
  }

  void _answerWritten() {
    if (_outcome != null) {
      _next();
      return;
    }
    if (_input.text.trim().isEmpty) return;
    _responseMs = _watch.elapsedMilliseconds;
    setState(() {
      _given = _input.text;
      _outcome = _session!.answerWritten(_input.text);
    });
  }

  void _override() {
    setState(() {
      _session!.overrideLast(_outcome!);
      _overridden = true;
    });
  }

  void _next() {
    final o = _outcome!;
    final Rating rating;
    if (_overridden) {
      rating = Rating.good;
    } else if (o.grade != null) {
      rating = ratingForGrade(o.grade!);
    } else {
      rating = o.accepted ? Rating.good : Rating.again;
    }
    recordAnswer(
      o.question.card.id,
      StudyMode.learn,
      rating,
      correct: o.accepted || _overridden,
      responseMs: _responseMs,
    );
    setState(() {
      _session!.next();
      _outcome = null;
      _given = null;
      _overridden = false;
      _input.clear();
    });
    _watch
      ..reset()
      ..start();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s == null || s.isFinished
              ? 'Lernmodus'
              : '${s.masteredCount} von ${s.total} gemeistert',
        ),
        bottom: s == null ? null : progressBar(s.progress),
      ),
      body: SafeArea(child: _body(s)),
    );
  }

  Widget _body(LearnSession? s) {
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (s.total == 0) {
      return const StudyEmpty(message: 'Keine Karten zum Lernen.');
    }
    if (s.isFinished) {
      final trouble = s.troubleCards;
      return SessionSummary(
        title: 'Alle ${s.total} Karten gemeistert!',
        lines: [
          if (trouble.isEmpty)
            'Ohne einen einzigen Fehler.'
          else
            'Diese Karten waren knifflig:',
        ],
        onDone: () => context.pop(),
        children: [
          for (final c in trouble)
            ListTile(
              dense: true,
              title: Text(c.front),
              subtitle: Text(c.back),
              trailing: Text('${s.mistakesOf(c)}× falsch'),
            ),
        ],
      );
    }
    final q = s.current;
    final o = _outcome;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PromptCard(
          card: q.card,
          direction: q.direction,
          languageLabel: languageLabel,
        ),
        const SizedBox(height: 8),
        Text(
          q.type == LearnQuestionType.multipleChoice
              ? 'Wähle die richtige Antwort'
              : 'Schreibe die Antwort',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        if (q.type == LearnQuestionType.multipleChoice)
          for (final choice in q.choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoiceButton(
                text: choice,
                state: o == null
                    ? _ChoiceState.neutral
                    : choice == q.expected
                    ? _ChoiceState.correct
                    : choice == _given
                    ? _ChoiceState.wrong
                    : _ChoiceState.neutral,
                onTap: () => _answerChoice(choice),
              ),
            )
        else if (o == null)
          WrittenAnswerInput(
            controller: _input,
            focusNode: _focus,
            onSubmit: _answerWritten,
            answerLanguage: answerLanguage(q.direction),
            hint: q.direction == AskDirection.foreignToGerman
                ? 'Auf Deutsch'
                : 'Auf $languageLabel',
          ),
        if (o != null) ...[
          if (q.type == LearnQuestionType.written)
            AnswerFeedback(
              accepted: o.accepted,
              expected: q.expected,
              given: _given,
              grade: o.grade,
              overridden: _overridden,
              onOverride: _override,
            )
          else
            AnswerFeedback(accepted: o.accepted, expected: q.expected),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('nextQuestion'),
            autofocus: true,
            onPressed: _next,
            child: const Text('Weiter'),
          ),
        ],
      ],
    );
  }
}

enum _ChoiceState { neutral, correct, wrong }

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String text;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color? bg, IconData? icon) = switch (state) {
      _ChoiceState.correct => (
        Colors.green.withValues(alpha: 0.18),
        Icons.check,
      ),
      _ChoiceState.wrong => (scheme.error.withValues(alpha: 0.18), Icons.close),
      _ChoiceState.neutral => (null, null),
    };
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
          if (icon != null) Icon(icon),
        ],
      ),
    );
  }
}
