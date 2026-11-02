import 'package:barstardo_learning/core/learning/fsrs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fsrs = Fsrs();
  final t0 = DateTime(2026, 1, 1, 12);

  test('Retrievability bei t = S ist 90 %', () {
    expect(fsrs.retrievability(10, 10), closeTo(0.9, 1e-9));
    expect(fsrs.retrievability(0, 10), 1.0);
  });

  test('Intervall entspricht bei 90 % Ziel der Stabilität', () {
    expect(fsrs.intervalDays(15.4), 15);
    expect(fsrs.intervalDays(0.2), 1); // Minimum 1 Tag
  });

  test('Erste Abfrage: Startwerte nach Bewertung', () {
    final good = fsrs.review(null, Rating.good, t0);
    expect(good.stability, closeTo(3.1262, 1e-9));
    expect(good.difficulty, closeTo(7.2102, 1e-9));
    expect(good.reps, 1);
    expect(good.lapses, 0);
    expect(good.due, t0.add(const Duration(days: 3)));

    final again = fsrs.review(null, Rating.again, t0);
    expect(again.due, t0.add(const Duration(minutes: 10)));
    expect(again.lapses, 1);

    final easy = fsrs.review(null, Rating.easy, t0);
    expect(easy.due.isAfter(good.due), isTrue);
    expect(easy.difficulty, lessThan(good.difficulty));
  });

  test('Schwierigkeit bleibt zwischen 1 und 10', () {
    var m = fsrs.review(null, Rating.again, t0);
    for (var i = 0; i < 20; i++) {
      m = fsrs.review(m, Rating.again, m.due);
    }
    expect(m.difficulty, inInclusiveRange(1, 10));
    var e = fsrs.review(null, Rating.easy, t0);
    for (var i = 0; i < 20; i++) {
      e = fsrs.review(e, Rating.easy, e.due);
    }
    expect(e.difficulty, inInclusiveRange(1, 10));
  });

  test(
    'Wiederholtes „Gut“ zum Fälligkeitstermin verlängert die Intervalle',
    () {
      var m = fsrs.review(null, Rating.good, t0);
      var lastInterval = m.due.difference(t0);
      for (var i = 0; i < 5; i++) {
        final now = m.due;
        m = fsrs.review(m, Rating.good, now);
        final interval = m.due.difference(now);
        expect(interval, greaterThan(lastInterval));
        lastInterval = interval;
      }
      expect(m.reps, 6);
    },
  );

  test('Leicht > Gut > Schwer bei einer Wiederholung', () {
    final m = fsrs.review(null, Rating.good, t0);
    final p = fsrs.preview(m, m.due);
    expect(p[Rating.easy]!, greaterThan(p[Rating.good]!));
    expect(p[Rating.good]!, greaterThan(p[Rating.hard]!));
    expect(p[Rating.again], const Duration(minutes: 10));
  });

  test('„Nochmal“ senkt Stabilität und zählt Lapse', () {
    var m = fsrs.review(null, Rating.good, t0);
    m = fsrs.review(m, Rating.good, m.due);
    final before = m.stability;
    final failed = fsrs.review(m, Rating.again, m.due);
    expect(failed.stability, lessThan(before));
    expect(failed.lapses, 1);
    expect(failed.difficulty, greaterThan(m.difficulty));
  });

  test('Abfrage am selben Tag ändert die Stabilität kaum', () {
    final m = fsrs.review(null, Rating.good, t0);
    final again = fsrs.review(
      m,
      Rating.good,
      t0.add(const Duration(minutes: 1)),
    );
    expect(again.stability, closeTo(m.stability, 0.01));
  });

  test('formatInterval', () {
    expect(formatInterval(const Duration(minutes: 10)), '10 Min.');
    expect(formatInterval(const Duration(hours: 5)), '5 Std.');
    expect(formatInterval(const Duration(days: 3)), '3 T.');
    expect(formatInterval(const Duration(days: 90)), '3 Mon.');
    expect(formatInterval(const Duration(days: 730)), '2 J.');
    expect(formatInterval(const Duration(days: 547)), '1,5 J.');
  });
}
