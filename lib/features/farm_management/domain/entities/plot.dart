import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class Plot extends Equatable {
  final String id;
  final String farmId;
  final String name;
  final double areaRai;
  final String cropType;
  final String? sensorDeviceToken;
  final bool isDeleted;
  final DateTime createdAt;
  final List<LatLng> boundary;

  const Plot({
    required this.id,
    required this.farmId,
    required this.name,
    required this.areaRai,
    required this.cropType,
    this.sensorDeviceToken,
    this.isDeleted = false,
    required this.createdAt,
    this.boundary = const [],
  });

  @override
  List<Object?> get props => [id, farmId, name, areaRai, cropType, boundary];
}
