import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/soil_survey/domain/entities/soil_sample.dart';
import 'package:chaona_app/features/soil_survey/domain/services/soil_survey_calculator.dart';

void main() {
  test('summary uses median and reports valid sample count', () {
    final summary = SoilSurveyCalculator().summarize(
      plotId: 'plot-1',
      samples: [
        _sample('a', 10, 20, 30),
        _sample('b', 30, 40, 50),
        _sample('c', 20, 30, 40),
      ],
      now: DateTime(2026, 8, 12),
    );

    expect(summary.medianNitrogen, 20);
    expect(summary.validSampleCount, 3);
  });
}

SoilSample _sample(String id, double n, double p, double k) => SoilSample(
      id: id,
      plotId: 'plot-1',
      samplingPointId: 'point-$id',
      nitrogen: n,
      phosphorus: p,
      potassium: k,
      sampledAt: DateTime(2026, 8, 11),
    );
