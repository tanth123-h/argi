import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/recommendations/domain/entities/recommendation.dart';
import 'package:chaona_app/features/recommendations/domain/entities/risk_level.dart';
import 'package:chaona_app/features/recommendations/domain/entities/source_reference.dart';

void main() {
  test('recommendation equality includes source and action identity', () {
    final source = SourceReference(
      title: 'Crop water needs',
      publisher: 'FAO',
      url: Uri.parse('https://www.fao.org/4/s2022e/s2022e02.htm'),
      topic: 'water',
      reviewedAt: DateTime(2026, 8, 12),
    );
    final recommendation = Recommendation(
      id: 'water-1',
      title: 'Water check',
      action: 'Check soil moisture',
      level: RiskLevel.watch,
      value: 'Input needed',
      calculation: 'ETc = ETo x Kc',
      confidence: 0.4,
      source: source,
      createdAt: DateTime(2026, 8, 12),
    );

    expect(recommendation.source.publisher, 'FAO');
    expect(recommendation.level, RiskLevel.watch);
  });
}
