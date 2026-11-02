import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/learning/fsrs.dart';
import '../../core/learning/grading.dart';
import '../../core/learning/study_item.dart';
import '../../core/study_language.dart';
import '../../data/database.dart';
import 'study_options.dart';

/// Gemeinsames Laden für alle Lernmodi eines Sets.
mixin StudySessionLoader<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  int get setId;
  StudyOptions get options;

  VocabSet? studySet;
  List<StudyCard>? cards;

  String get languageLabel => studySet == null
      ? 'Fremdsprache'
      : StudyLanguage.labelFor(studySet!.language);
  String get languageCode => studySet?.language ?? '';

  /// Sprachcode der erwarteten Antwort.
  String answerLanguage(AskDirection d) =>
      d == AskDirection.foreignToGerman ? 'de' : languageCode;

  DirectionPicker get directionPicker =>
      DirectionPicker(options.direction, ref.read(randomProvider));

  Future<void> loadStudy() async {
    final repo = ref.read(libraryRepositoryProvider);
    final set = await repo.getSet(setId);
    final list = await ref
        .read(studyRepositoryProvider)
        .loadCards(setId, starredOnly: options.starredOnly);
    if (!mounted) return;
    setState(() {
      studySet = set;
      cards = list;
    });
    onLoaded(list);
  }

  /// Wird nach dem Laden aufgerufen (Sitzung aufbauen).
  void onLoaded(List<StudyCard> cards);

  Future<void> recordAnswer(
    int cardId,
    String mode,
    Rating rating, {
    bool? correct,
    int? responseMs,
  }) {
    return ref
        .read(studyRepositoryProvider)
        .record(
          cardId: cardId,
          mode: mode,
          rating: rating,
          correct: correct,
          responseMs: responseMs,
        );
  }
}

/// Bewertung einer geschriebenen Antwort für FSRS.
Rating ratingForGrade(GradeResult grade, {bool overridden = false}) {
  if (overridden) return Rating.good;
  return switch (grade.verdict) {
    Verdict.correct => Rating.good,
    Verdict.almostCorrect => Rating.hard,
    Verdict.wrong => Rating.again,
  };
}

/// Fragt beim Verlassen einer laufenden Sitzung nach.
Future<bool> confirmLeave(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sitzung beenden?'),
      content: const Text('Bisherige Antworten bleiben gespeichert.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Weiterlernen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Beenden'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
