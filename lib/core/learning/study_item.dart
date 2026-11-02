import 'dart:math';

import '../../features/settings/app_settings.dart';

/// Richtung einer einzelnen Frage.
enum AskDirection {
  /// Fremdwort zeigen, Deutsch abfragen.
  foreignToGerman,

  /// Deutsch zeigen, Fremdwort abfragen.
  germanToForeign,
}

/// Eine Karte in der Form, die die Lernmodi brauchen (unabhängig von Drift).
class StudyCard {
  const StudyCard({
    required this.id,
    required this.front,
    required this.back,
    this.frontRich,
    this.backRich,
    this.imagePath,
    this.starred = false,
  });

  final int id;

  /// Fremdwort.
  final String front;

  /// Deutsch.
  final String back;
  final String? frontRich;
  final String? backRich;
  final String? imagePath;
  final bool starred;

  String promptFor(AskDirection d) =>
      d == AskDirection.foreignToGerman ? front : back;
  String? promptRichFor(AskDirection d) =>
      d == AskDirection.foreignToGerman ? frontRich : backRich;
  String answerFor(AskDirection d) =>
      d == AskDirection.foreignToGerman ? back : front;
  String? answerRichFor(AskDirection d) =>
      d == AskDirection.foreignToGerman ? backRich : frontRich;

  @override
  bool operator ==(Object other) => other is StudyCard && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StudyCard($id: $front | $back)';
}

/// Wählt die Richtung pro Frage gemäß Einstellung (gemischt = zufällig).
class DirectionPicker {
  DirectionPicker(this.setting, [Random? random])
    : _random = random ?? Random();

  final QuizDirection setting;
  final Random _random;

  AskDirection next() => switch (setting) {
    QuizDirection.foreignToGerman => AskDirection.foreignToGerman,
    QuizDirection.germanToForeign => AskDirection.germanToForeign,
    QuizDirection.mixed =>
      _random.nextBool()
          ? AskDirection.foreignToGerman
          : AskDirection.germanToForeign,
  };
}

/// Antwortmöglichkeiten für Multiple Choice: die richtige Antwort plus bis zu
/// [count] - 1 Ablenker aus anderen Karten (ohne doppelte Texte).
List<String> choicesFor(
  StudyCard card,
  AskDirection direction,
  List<StudyCard> pool,
  Random random, {
  int count = 4,
}) {
  final correct = card.answerFor(direction);
  final seen = {correct.trim().toLowerCase()};
  final others = [...pool]..shuffle(random);
  final options = [correct];
  for (final c in others) {
    if (options.length >= count) break;
    if (c.id == card.id) continue;
    final text = c.answerFor(direction);
    if (seen.add(text.trim().toLowerCase())) options.add(text);
  }
  options.shuffle(random);
  return options;
}
