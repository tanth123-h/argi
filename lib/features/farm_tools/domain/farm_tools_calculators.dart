import 'package:equatable/equatable.dart';

class WaterEstimate extends Equatable {
  final double etcMmPerDay;
  final double netMmPerDay;
  final double volumeM3PerDay;
  const WaterEstimate({
    required this.etcMmPerDay,
    required this.netMmPerDay,
    required this.volumeM3PerDay,
  });
  @override
  List<Object?> get props => [etcMmPerDay, netMmPerDay, volumeM3PerDay];
}

class FarmWaterCalculator {
  const FarmWaterCalculator();

  WaterEstimate calculate({
    required double etoMmPerDay,
    required double kc,
    required double effectiveRainMm,
    required double areaRai,
  }) {
    final etc = etoMmPerDay * kc;
    final net = (etc - effectiveRainMm).clamp(0, double.infinity).toDouble();
    return WaterEstimate(
      etcMmPerDay: etc,
      netMmPerDay: net,
      volumeM3PerDay: net * areaRai * 1600 / 1000,
    );
  }
}

class FarmEconomics {
  const FarmEconomics();

  double revenue({
    required double yieldTonsPerRai,
    required double areaRai,
    required double pricePerKg,
  }) => yieldTonsPerRai * areaRai * 1000 * pricePerKg;
  double totalCost({required double costPerRai, required double areaRai}) =>
      costPerRai * areaRai;
  double profit({
    required double yieldTonsPerRai,
    required double areaRai,
    required double pricePerKg,
    required double costPerRai,
  }) =>
      revenue(
        yieldTonsPerRai: yieldTonsPerRai,
        areaRai: areaRai,
        pricePerKg: pricePerKg,
      ) -
      totalCost(costPerRai: costPerRai, areaRai: areaRai);
}
