import 'package:chaona_app/features/soil_monitoring/domain/entities/soil_data.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/soil_health_score.dart';
import 'package:chaona_app/core/constants/app_constants.dart';

/// Pure soil health score calculations — no external dependencies.
class SoilCalculator {
  SoilCalculator._();

  /// Moisture score: 100 if in optimal range (30–70%), else decays linearly.
  /// Formula: max(0, 100 - |M - 55| * 2.5)
  static double moistureScore(double moisture) {
    if (moisture >= AppConstants.moistureOptimalMin &&
        moisture <= AppConstants.moistureOptimalMax) {
      return 100.0;
    }
    final deviation = (moisture - 55).abs();
    return (100 - deviation * 2.5).clamp(0.0, 100.0);
  }

  /// NPK subscore: 100 in normal range (30–70 mg/kg).
  /// Low (<30): linear scale up from 0
  /// High (>70): linear decay from 100
  static double npkScore(double value) {
    if (value >= AppConstants.npkLowThreshold &&
        value <= AppConstants.npkHighThreshold) {
      return 100.0;
    }
    if (value < AppConstants.npkLowThreshold) {
      return (value / AppConstants.npkLowThreshold * 100).clamp(0.0, 100.0);
    }
    // value > 70
    return (100 - (value - AppConstants.npkHighThreshold) * 2.5)
        .clamp(0.0, 100.0);
  }

  /// Composite score = average of four equally-weighted subscores.
  static SoilHealthScore calculate(SoilData data) {
    final mScore = moistureScore(data.moisture);
    final nScore = npkScore(data.nitrogen);
    final pScore = npkScore(data.phosphorus);
    final kScore = npkScore(data.potassium);
    final composite = (mScore + nScore + pScore + kScore) / 4.0;
    return SoilHealthScore(
      composite: composite,
      moistureScore: mScore,
      nScore: nScore,
      pScore: pScore,
      kScore: kScore,
    );
  }

  /// Nutrient status label for display.
  static NutrientStatus moistureStatus(double moisture) {
    if (moisture < AppConstants.moistureWarningThreshold) {
      return NutrientStatus.low;
    }
    if (moisture > AppConstants.moistureOptimalMax) return NutrientStatus.high;
    return NutrientStatus.normal;
  }

  static NutrientStatus npkStatus(double value) {
    if (value < AppConstants.npkLowThreshold) return NutrientStatus.low;
    if (value > AppConstants.npkHighThreshold) return NutrientStatus.high;
    return NutrientStatus.normal;
  }
}

enum NutrientStatus { low, normal, high }
