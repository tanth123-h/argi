import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/recommendations/domain/rules/rice_rule.dart';
import 'package:chaona_app/features/recommendations/domain/rules/crop_rule.dart';
import 'package:chaona_app/features/recommendations/domain/services/recommendation_engine.dart';
import 'package:chaona_app/features/soil_survey/domain/entities/soil_plot_summary.dart';

void main() {
  test('rice rule emits drought warning from low moisture', () {
    final results = RecommendationEngine(rules: [RiceRule()]).evaluate(
      _context(moisture: 18),
    );

    expect(results.any((r) => r.id == 'drought-risk'), isTrue);
    expect(results.singleWhere((r) => r.id == 'drought-risk').source.publisher, isNotEmpty);
  });

  test('watering result shows missing evapotranspiration inputs', () {
    final results = RecommendationEngine(rules: [RiceRule()]).evaluate(
      _context(moisture: 55),
    );

    expect(results.any((r) => r.id == 'watering-input-needed'), isTrue);
  });
}

RecommendationContext _context({required double moisture}) => RecommendationContext(
      soil: SoilPlotSummary(
        plotId: 'plot-1',
        medianNitrogen: 40,
        medianPhosphorus: 40,
        medianPotassium: 40,
        medianMoisture: moisture,
        validSampleCount: 5,
        confidence: SampleConfidence.high,
        latestSampleAt: DateTime(2026, 8, 12),
      ),
      plotAreaRai: 5,
      cropId: 'rice',
      now: DateTime(2026, 8, 12),
    );
