import 'package:equatable/equatable.dart';

enum SampleConfidence { low, medium, high }

class SoilPlotSummary extends Equatable {
  final String plotId;
  final double? medianNitrogen;
  final double? medianPhosphorus;
  final double? medianPotassium;
  final double? medianPh;
  final double? medianMoisture;
  final int validSampleCount;
  final SampleConfidence confidence;
  final DateTime? latestSampleAt;

  const SoilPlotSummary({
    required this.plotId,
    this.medianNitrogen,
    this.medianPhosphorus,
    this.medianPotassium,
    this.medianPh,
    this.medianMoisture,
    required this.validSampleCount,
    required this.confidence,
    this.latestSampleAt,
  });

  @override
  List<Object?> get props => [
        plotId,
        medianNitrogen,
        medianPhosphorus,
        medianPotassium,
        medianPh,
        medianMoisture,
        validSampleCount,
        confidence,
        latestSampleAt,
      ];
}
