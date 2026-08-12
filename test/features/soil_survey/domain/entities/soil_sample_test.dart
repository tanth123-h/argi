import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/soil_survey/domain/entities/soil_sample.dart';

void main() {
  test('soil sample equality includes measurement identity', () {
    final a = SoilSample(
      id: 'sample-1',
      plotId: 'plot-1',
      samplingPointId: 'point-1',
      nitrogen: 20,
      phosphorus: 30,
      potassium: 40,
    );
    final b = SoilSample(
      id: 'sample-1',
      plotId: 'plot-1',
      samplingPointId: 'point-1',
      nitrogen: 20,
      phosphorus: 30,
      potassium: 40,
    );

    expect(a, equals(b));
  });
}
