import 'package:flutter_test/flutter_test.dart';
import 'package:chaona_app/features/ai_chat/domain/ai_context_builder.dart';
import 'package:chaona_app/features/auth/data/demo/demo_fixtures.dart';
import 'package:chaona_app/features/recommendations/data/source_catalog.dart';
import 'package:chaona_app/features/recommendations/domain/entities/recommendation.dart';
import 'package:chaona_app/features/recommendations/domain/entities/risk_level.dart';

void main() {
  test('AI context contains source URL and numeric-safety instruction', () {
    final recommendation = Recommendation(
      id: 'drought-risk',
      title: 'Drought screening alert',
      action: 'Check water access',
      level: RiskLevel.urgent,
      value: '18% soil moisture',
      calculation: 'Screening threshold: moisture below 20%',
      confidence: 0.9,
      source: SourceCatalog.riceWaterRequirements,
      createdAt: DateTime(2026, 8, 12),
    );

    final context = AiContextBuilder().build(
      farm: DemoFixtures.farmA,
      recommendations: [recommendation],
    );

    expect(context, contains(recommendation.source.url.toString()));
    expect(context, contains('ห้ามสร้างตัวเลขหรือแหล่งอ้างอิงใหม่'));
  });
}
