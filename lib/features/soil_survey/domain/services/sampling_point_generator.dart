import 'package:latlong2/latlong.dart';
import '../entities/sampling_point.dart';

enum SamplingPattern { zigzag, grid }

class SamplingPointGenerator {
  /// Field-screening recommendation based on LDD guidance of roughly
  /// 15-20 points across a 10-20 rai management area. A laboratory composite
  /// sample is still required for fertilizer decisions.
  static int recommendedCount(double areaRai) {
    final points = (areaRai * 1.5).ceil();
    return points.clamp(5, 60).toInt();
  }

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
    // Keep both grid and zigzag layouts balanced. Using `count` rows with one
    // column made large fields look like a single line of sampling points.
    final rows = count.ceilSqrt();
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
    // A narrow or rotated field can reject most bounding-box grid points.
    // Use several rings from the centroid, while de-duplicating coordinates.
    for (var ring = 1; candidates.length < count && ring <= 8; ring++) {
      final factor = ring / 9;
      for (final edge in boundary) {
        if (candidates.length >= count) break;
        final candidate = LatLng(
          center.latitude + (edge.latitude - center.latitude) * factor,
          center.longitude + (edge.longitude - center.longitude) * factor,
        );
        if (_contains(boundary, candidate) && !_containsDuplicate(candidates, candidate)) {
          candidates.add(candidate);
        }
      }
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

  bool _containsDuplicate(List<LatLng> points, LatLng candidate) => points.any(
        (point) =>
            (point.latitude - candidate.latitude).abs() < 0.0000001 &&
            (point.longitude - candidate.longitude).abs() < 0.0000001,
      );

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
