import '../entities/recommendation.dart';
import '../../../soil_survey/domain/entities/soil_plot_summary.dart';

class RecommendationContext {
  final SoilPlotSummary? soil;
  final double plotAreaRai;
  final String cropId;
  final double? etoMm;
  final double? kc;
  final double? effectiveRainMm;
  final DateTime now;

  const RecommendationContext({
    required this.soil,
    required this.plotAreaRai,
    required this.cropId,
    this.etoMm,
    this.kc,
    this.effectiveRainMm,
    required this.now,
  });
}

abstract interface class CropRule {
  String get cropId;

  List<Recommendation> evaluate(RecommendationContext context);
}
