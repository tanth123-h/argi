import '../entities/soil_plot_summary.dart';
import '../entities/soil_sample.dart';

class SoilSurveyCalculator {
  SoilPlotSummary summarize({
    required String plotId,
    required List<SoilSample> samples,
    required DateTime now,
  }) {
    final valid = samples.where(_hasValidNpk).toList();
    final dates = valid.map((s) => s.sampledAt).whereType<DateTime>().toList();
    dates.sort();
    final latest = dates.isEmpty ? null : dates.last;
    return SoilPlotSummary(
      plotId: plotId,
      medianNitrogen: median(valid.map((s) => s.nitrogen)),
      medianPhosphorus: median(valid.map((s) => s.phosphorus)),
      medianPotassium: median(valid.map((s) => s.potassium)),
      medianPh: median(valid.map((s) => s.ph).whereType<double>()),
      medianMoisture: median(valid.map((s) => s.moisture).whereType<double>()),
      validSampleCount: valid.length,
      latestSampleAt: latest,
      confidence: confidence(
        expectedCount: 5,
        validCount: valid.length,
        latestSampleAt: latest,
        now: now,
      ),
    );
  }

  double? median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return null;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  SampleConfidence confidence({
    required int expectedCount,
    required int validCount,
    required DateTime? latestSampleAt,
    required DateTime now,
  }) {
    if (latestSampleAt == null || now.difference(latestSampleAt).inDays > 30) {
      return SampleConfidence.low;
    }
    final coverage = expectedCount == 0 ? 0 : validCount / expectedCount;
    if (coverage >= 0.8) return SampleConfidence.high;
    if (coverage >= 0.5) return SampleConfidence.medium;
    return SampleConfidence.low;
  }

  bool _hasValidNpk(SoilSample sample) =>
      sample.nitrogen >= 0 && sample.phosphorus >= 0 && sample.potassium >= 0;
}
