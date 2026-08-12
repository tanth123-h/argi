import '../../../soil_survey/domain/entities/soil_plot_summary.dart';
import '../../data/source_catalog.dart';
import '../entities/recommendation.dart';
import '../entities/risk_level.dart';
import 'crop_rule.dart';

class RiceRule implements CropRule {
  const RiceRule();

  @override
  String get cropId => 'rice';

  @override
  List<Recommendation> evaluate(RecommendationContext context) {
    final results = <Recommendation>[];
    final soil = context.soil;

    if (soil?.medianMoisture != null && soil!.medianMoisture! < 20) {
      results.add(Recommendation(
        id: 'drought-risk',
        title: 'Drought screening alert',
        action: 'Check water access and inspect the plot today.',
        level: RiskLevel.urgent,
        value: '${soil.medianMoisture!.toStringAsFixed(0)}% soil moisture',
        calculation: 'Screening threshold: moisture below 20%',
        confidence: _confidence(soil),
        source: SourceCatalog.riceWaterRequirements,
        createdAt: context.now,
      ));
    }

    if (soil?.medianMoisture != null && soil!.medianMoisture! > 70) {
      results.add(Recommendation(
        id: 'waterlogging-risk',
        title: 'High moisture screening alert',
        action: 'Inspect drainage and avoid adding water until the plot is checked.',
        level: RiskLevel.watch,
        value: '${soil.medianMoisture!.toStringAsFixed(0)}% soil moisture',
        calculation: 'Screening threshold: moisture above 70%',
        confidence: _confidence(soil),
        source: SourceCatalog.riceCropWaterNeeds,
        createdAt: context.now,
      ));
    }

    if (context.etoMm != null && context.kc != null) {
      final etc = context.etoMm! * context.kc!;
      final net = (etc - (context.effectiveRainMm ?? 0)).clamp(0, double.infinity);
      results.add(Recommendation(
        id: 'watering-estimate',
        title: 'Estimated crop water need',
        action: 'Use this as a starting estimate and check field conditions.',
        level: RiskLevel.info,
        value: '${net.toStringAsFixed(1)} mm/day',
        calculation: 'ETc = ETo x Kc; net = ETc - effective rainfall',
        confidence: soil == null ? 0.5 : _confidence(soil),
        source: SourceCatalog.riceWaterRequirements,
        createdAt: context.now,
      ));
    } else {
      results.add(Recommendation(
        id: 'watering-input-needed',
        title: 'Watering estimate needs more input',
        action: 'Add weather ETo and rice growth-stage Kc before using a water volume.',
        level: RiskLevel.watch,
        value: 'ETo + Kc required',
        calculation: 'ETc = ETo x Kc',
        confidence: 0,
        source: SourceCatalog.riceWaterRequirements,
        createdAt: context.now,
      ));
    }

    results.add(Recommendation(
      id: 'rice-spacing',
      title: 'Rice planting spacing reference',
      action: 'Use local planting method and field condition to choose final spacing.',
      level: RiskLevel.info,
      value: '20 x 20 cm; 3-5 seedlings/clump reference',
      calculation: 'Reference range from Thai Rice Department guidance',
      confidence: 0.7,
      source: SourceCatalog.riceSpacing,
      createdAt: context.now,
    ));
    return results;
  }

  double _confidence(SoilPlotSummary soil) => switch (soil.confidence) {
        SampleConfidence.high => 0.9,
        SampleConfidence.medium => 0.6,
        SampleConfidence.low => 0.3,
      };
}
