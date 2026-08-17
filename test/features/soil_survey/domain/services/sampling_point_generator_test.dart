import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:chaona_app/features/soil_survey/domain/services/sampling_point_generator.dart';

void main() {
  test('zigzag generator returns requested points inside rectangular boundary', () {
    final points = SamplingPointGenerator().generate(
      plotId: 'plot-1',
      boundary: const [
        LatLng(14, 100),
        LatLng(14, 100.01),
        LatLng(14.01, 100.01),
        LatLng(14.01, 100),
      ],
      count: 5,
    );

    expect(points, hasLength(5));
    expect(points.every((p) => p.latitude >= 14 && p.latitude <= 14.01), isTrue);
    expect(points.every((p) => p.longitude >= 100 && p.longitude <= 100.01), isTrue);
    expect(points.map((p) => p.id).toSet(), hasLength(5));
  });

  test('recommended count scales with farm area and has a small-farm minimum', () {
    expect(SamplingPointGenerator.recommendedCount(1), 5);
    expect(SamplingPointGenerator.recommendedCount(10), 15);
    expect(SamplingPointGenerator.recommendedCount(50), 60);
  });

  test('does not collapse a multi-point field survey into one line', () {
    final points = SamplingPointGenerator().generate(
      plotId: 'plot-2',
      boundary: const [
        LatLng(14, 100),
        LatLng(14, 100.02),
        LatLng(14.01, 100.02),
        LatLng(14.01, 100),
      ],
      count: 14,
    );

    expect(points, hasLength(14));
    expect(points.map((p) => p.longitude).toSet().length, greaterThan(1));
    expect(points.map((p) => p.latitude).toSet().length, greaterThan(1));
    expect(
      points.map((p) => '${p.latitude},${p.longitude}').toSet(),
      hasLength(14),
    );
  });
}
