import 'dart:math' as math;

/// Bewertung einer Abfrage (FSRS: 1 = Nochmal … 4 = Leicht).
enum Rating {
  again(1, 'Nochmal'),
  hard(2, 'Schwer'),
  good(3, 'Gut'),
  easy(4, 'Leicht');

  const Rating(this.value, this.label);

  final int value;
  final String label;
}

/// Zustand einer Karte im Spaced-Repetition-System.
class CardMemory {
  const CardMemory({
    required this.due,
    required this.stability,
    required this.difficulty,
    required this.reps,
    required this.lapses,
    required this.lastReview,
  });

  final DateTime due;

  /// Tage, nach denen die Abrufwahrscheinlichkeit auf 90 % gefallen ist.
  final double stability;

  /// 1 (leicht) … 10 (schwer).
  final double difficulty;
  final int reps;
  final int lapses;
  final DateTime? lastReview;

  @override
  String toString() =>
      'CardMemory(due: $due, S: ${stability.toStringAsFixed(2)}, '
      'D: ${difficulty.toStringAsFixed(2)}, reps: $reps, lapses: $lapses)';
}

/// FSRS-4.5-Scheduler (Free Spaced Repetition Scheduler) mit den
/// veröffentlichten Standardgewichten.
///
/// Vereinfachungen gegenüber Anki: Keine Lernschritte außer einem
/// 10-Minuten-Schritt nach „Nochmal“; Intervalle in ganzen Tagen.
class Fsrs {
  const Fsrs({
    this.weights = defaultWeights,
    this.desiredRetention = 0.9,
    this.maximumInterval = 36500,
    this.relearnDelay = const Duration(minutes: 10),
  });

  static const defaultWeights = [
    0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616, //
    0.1544, 1.0824, 1.9813, 0.0953, 0.2975, 2.2042, 0.2407, 2.9466,
  ];

  static const double decay = -0.5;
  static const double factor = 19 / 81;

  final List<double> weights;
  final double desiredRetention;
  final int maximumInterval;
  final Duration relearnDelay;

  double _w(int i) => weights[i];

  /// Abrufwahrscheinlichkeit nach [elapsedDays] Tagen bei Stabilität [s].
  double retrievability(double elapsedDays, double s) =>
      math.pow(1 + factor * elapsedDays / s, decay).toDouble();

  /// Intervall in Tagen, nach dem R auf [desiredRetention] fällt.
  int intervalDays(double s) {
    final i = s / factor * (math.pow(desiredRetention, 1 / decay) - 1);
    return i.round().clamp(1, maximumInterval);
  }

  double initialStability(Rating r) => math.max(_w(r.value - 1), 0.1);

  double initialDifficulty(Rating r) =>
      (_w(4) - (r.value - 3) * _w(5)).clamp(1.0, 10.0);

  double nextDifficulty(double d, Rating r) {
    final next = d - _w(6) * (r.value - 3);
    final reverted =
        _w(7) * initialDifficulty(Rating.easy) + (1 - _w(7)) * next;
    return reverted.clamp(1.0, 10.0);
  }

  double recallStability(double d, double s, double r, Rating rating) {
    final hardPenalty = rating == Rating.hard ? _w(15) : 1.0;
    final easyBonus = rating == Rating.easy ? _w(16) : 1.0;
    return s *
        (1 +
            math.exp(_w(8)) *
                (11 - d) *
                math.pow(s, -_w(9)) *
                (math.exp((1 - r) * _w(10)) - 1) *
                hardPenalty *
                easyBonus);
  }

  double forgetStability(double d, double s, double r) {
    final next =
        _w(11) *
        math.pow(d, -_w(12)) *
        (math.pow(s + 1, _w(13)) - 1) *
        math.exp((1 - r) * _w(14));
    return math.min(next, s);
  }

  /// Berechnet den neuen Zustand nach einer Abfrage.
  /// [memory] == null bedeutet: Karte wird zum ersten Mal gelernt.
  CardMemory review(CardMemory? memory, Rating rating, DateTime now) {
    if (memory == null || memory.lastReview == null || memory.reps == 0) {
      final s = initialStability(rating);
      final d = initialDifficulty(rating);
      return CardMemory(
        due: rating == Rating.again
            ? now.add(relearnDelay)
            : now.add(Duration(days: intervalDays(s))),
        stability: s,
        difficulty: d,
        reps: 1,
        lapses: rating == Rating.again ? 1 : 0,
        lastReview: now,
      );
    }

    final elapsed = math.max(
      0.0,
      now.difference(memory.lastReview!).inMinutes / 1440.0,
    );
    final r = retrievability(elapsed, memory.stability);
    final d = nextDifficulty(memory.difficulty, rating);
    if (rating == Rating.again) {
      return CardMemory(
        due: now.add(relearnDelay),
        stability: math.max(
          forgetStability(memory.difficulty, memory.stability, r),
          0.1,
        ),
        difficulty: d,
        reps: memory.reps + 1,
        lapses: memory.lapses + 1,
        lastReview: now,
      );
    }
    final s = recallStability(memory.difficulty, memory.stability, r, rating);
    return CardMemory(
      due: now.add(Duration(days: intervalDays(s))),
      stability: s,
      difficulty: d,
      reps: memory.reps + 1,
      lapses: memory.lapses,
      lastReview: now,
    );
  }

  /// Vorschau: Nach welcher Zeit kommt die Karte bei jeder Bewertung wieder?
  Map<Rating, Duration> preview(CardMemory? memory, DateTime now) => {
    for (final r in Rating.values)
      r: review(memory, r, now).due.difference(now),
  };
}

/// „10 Min.“, „3 T.“, „2 Mon.“, „1,5 J.“
String formatInterval(Duration d) {
  if (d.inMinutes < 60) return '${math.max(1, d.inMinutes)} Min.';
  if (d.inHours < 24) return '${d.inHours} Std.';
  final days = d.inHours / 24;
  if (days < 30) return '${days.round()} T.';
  if (days < 365) return '${(days / 30).round()} Mon.';
  final years = days / 365;
  return '${years.toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} J.';
}
