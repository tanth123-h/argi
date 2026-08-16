import 'package:equatable/equatable.dart';

enum SampleSource { handheld, fixedSensor }

class SoilSample extends Equatable {
  final String id;
  final String plotId;
  final String samplingPointId;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double? ph;
  final double? moisture;
  final double? temperature;
  final DateTime? sampledAt;
  final SampleSource source;
  final String? note;

  const SoilSample({
    required this.id,
    required this.plotId,
    required this.samplingPointId,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    this.ph,
    this.moisture,
    this.temperature,
    this.sampledAt,
    this.source = SampleSource.handheld,
    this.note,
  });

  @override
  List<Object?> get props => [
        id,
        plotId,
        samplingPointId,
        nitrogen,
        phosphorus,
        potassium,
        ph,
        moisture,
        temperature,
        sampledAt,
        source,
        note,
      ];
}
