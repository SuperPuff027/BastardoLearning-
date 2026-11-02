import 'package:barstardo_learning/core/learning/test_generator.dart';
import 'package:barstardo_learning/features/settings/app_settings.dart';
import 'package:barstardo_learning/features/study/study_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StudyOptions: Roundtrip über Query-Parameter', () {
    const o = StudyOptions(
      direction: QuizDirection.germanToForeign,
      starredOnly: true,
      shuffle: false,
      questionCount: 7,
      testTypes: {TestQuestionType.written, TestQuestionType.matching},
    );
    expect(StudyOptions.fromQuery(o.toQuery()), o);
  });

  test('StudyOptions: Standardwerte bei leeren Parametern', () {
    final o = StudyOptions.fromQuery({});
    expect(o, const StudyOptions());
    expect(o.direction, QuizDirection.mixed);
    expect(o.testTypes, hasLength(4));
  });
}
