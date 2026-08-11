import 'package:equatable/equatable.dart';

class SoilData extends Equatable {
  final String id;
  final String farmId;
  final double moisture;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double phLevel;
  final double? temperature;
  final bool isDemoData;
  final DateTime createdAt;

  const SoilData({
    required this.id,
    required this.farmId,
    required this.moisture,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    this.phLevel = 6.5,
    this.temperature,
    this.isDemoData = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, farmId, createdAt];
}
