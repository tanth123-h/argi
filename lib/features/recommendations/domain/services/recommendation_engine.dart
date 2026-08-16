import '../entities/recommendation.dart';
import '../rules/crop_rule.dart';

class RecommendationEngine {
  final List<CropRule> rules;

  const RecommendationEngine({required this.rules});

  List<Recommendation> evaluate(RecommendationContext context) => rules
      .where((rule) => rule.cropId == context.cropId)
      .expand((rule) => rule.evaluate(context))
      .toList(growable: false);
}
