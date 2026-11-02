import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/learning/study_item.dart';
import '../../core/learning/write_session.dart';
import '../../data/study_repository.dart';
import 'session_base.dart';
import 'study_options.dart';
import 'study_widgets.dart';

/// Schreiben (Brief Nr. 13): Antwort eintippen.
class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({super.key, required this.setId, required this.options});

  final int setId;
  final StudyOptions options;

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen>
    with StudySessionLoader {
  @override
  int get setId => widget.setId;
  @override
  StudyOptions get options => widget.options;

  WriteSession? _session;
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
  void onLoaded(List<StudyCard> cards) {
    setState(() {
      _session = WriteSession(
        cards,
        directions: directionPicker,
        shuffle: options.shuffle,
        random: ref.read(randomProvider),
      );
    });
    _watch.start();
  }

  void _submit() {
    final s = _session!;
    if (s.pending != null) {
      _next();
      return;
    }
    if (_input.text.trim().isEmpty) return;
    _responseMs = _watch.elapsedMilliseconds;
    setState(() => s.submit(_input.text));
  }

  void _next() {
    final s = _session!;
    final a = s.pending!;
    recordAnswer(
      a.card.id,
      StudyMode.write,
      ratingForGrade(a.result, overridden: a.overridden),
      correct: a.accepted,
      responseMs: _responseMs,
    );
    setState(() {
      s.next();
      _input.clear();
    });
    _watch
      ..reset()
      ..start();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s == null || s.isFinished
              ? 'Schreiben'
              : 'Frage ${s.position + 1} von ${s.total}',
        ),
        bottom: s == null
            ? null
            : progressBar(s.total == 0 ? 1 : s.position / s.total),
      ),
      body: SafeArea(child: _body(s)),
    );
  }

  Widget _body(WriteSession? s) {
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (s.total == 0) {
      return const StudyEmpty(message: 'Keine Karten zum Lernen.');
    }
    if (s.isFinished) {
      final wrong = s.wrongCards.length;
      return SessionSummary(
        title: '${s.correctCount} von ${s.total} richtig',
        lines: [
          if (wrong == 0) 'Alles gewusst – super!' else '$wrong noch üben',
        ],
        retryLabel: wrong == 0 ? null : 'Falsche wiederholen ($wrong)',
        onRetry: wrong == 0
            ? null
            : () => setState(() => _session = s.retryWrong()),
        onDone: () => context.pop(),
      );
    }
    final pending = s.pending;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PromptCard(
          card: s.current,
          direction: s.direction,
          languageLabel: languageLabel,
        ),
        const SizedBox(height: 16),
        if (pending == null)
          WrittenAnswerInput(
            controller: _input,
            focusNode: _focus,
            onSubmit: _submit,
            answerLanguage: answerLanguage(s.direction),
            hint: s.direction == AskDirection.foreignToGerman
                ? 'Auf Deutsch'
                : 'Auf $languageLabel',
          )
        else ...[
          AnswerFeedback(
            accepted: pending.accepted,
            expected: pending.card.answerFor(pending.direction),
            given: pending.given,
            grade: pending.result,
            overridden: pending.overridden,
            onOverride: () => setState(s.overrideCorrect),
          ),
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
