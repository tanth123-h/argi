import 'package:latlong2/latlong.dart';
import '../entities/sampling_point.dart';

enum SamplingPattern { zigzag, grid }

class SamplingPointGenerator {
  List<SamplingPoint> generate({
    required String plotId,
    required List<LatLng> boundary,
    required int count,
    SamplingPattern pattern = SamplingPattern.zigzag,
  }) {
    if (boundary.length < 3 || count <= 0) return const [];

    final minLat = boundary.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = boundary.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng = boundary.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng = boundary.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    final rows = pattern == SamplingPattern.grid ? count.ceilSqrt() : count;
    final columns = (count / rows).ceil();
    final candidates = <LatLng>[];

    for (var row = 0; row < rows && candidates.length < count; row++) {
      final rowRatio = (row + 1) / (rows + 1);
      final reversed = pattern == SamplingPattern.zigzag && row.isOdd;
      for (var column = 0; column < columns && candidates.length < count; column++) {
        final columnIndex = reversed ? columns - column - 1 : column;
        final columnRatio = (columnIndex + 1) / (columns + 1);
        final candidate = LatLng(
          minLat + (maxLat - minLat) * rowRatio,
          minLng + (maxLng - minLng) * columnRatio,
        );
        if (_contains(boundary, candidate)) candidates.add(candidate);
      }
    }

    final center = LatLng(
      boundary.map((p) => p.latitude).reduce((a, b) => a + b) / boundary.length,
      boundary.map((p) => p.longitude).reduce((a, b) => a + b) / boundary.length,
    );
    var fallbackIndex = 0;
    while (candidates.length < count && fallbackIndex < boundary.length * 4) {
      final edge = boundary[fallbackIndex % boundary.length];
      final candidate = LatLng(
        center.latitude + (edge.latitude - center.latitude) * 0.5,
        center.longitude + (edge.longitude - center.longitude) * 0.5,
      );
      if (_contains(boundary, candidate)) candidates.add(candidate);
      fallbackIndex++;
    }

    return [
      for (var i = 0; i < candidates.length && i < count; i++)
        SamplingPoint(
          id: '$plotId-point-${i + 1}',
          plotId: plotId,
          sequence: i + 1,
          latitude: candidates[i].latitude,
          longitude: candidates[i].longitude,
        ),
    ];
  }

  bool _contains(List<LatLng> polygon, LatLng point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses = (a.latitude > point.latitude) != (b.latitude > point.latitude);
      if (crosses) {
        final lng = (b.longitude - a.longitude) *
                (point.latitude - a.latitude) /
                (b.latitude - a.latitude) +
            a.longitude;
        if (point.longitude < lng) inside = !inside;
      }
    }
    return inside;
  }
}

extension on int {
  int ceilSqrt() {
    var value = 1;
    while (value * value < this) value++;
    return value;
  }
}
