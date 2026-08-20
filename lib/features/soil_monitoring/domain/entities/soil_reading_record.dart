import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum SoilReadingSource { handheld, fixedSensor }

class SoilReadingRecord extends Equatable {
  final String clientReadingId;
  final String farmId;
  final String? plotId;
  final String? surveyId;
  final String? samplingPointId;
  final SoilReadingSource source;
  final String deviceId;
  final double? latitude;
  final double? longitude;
  final double? moisture;
  final double? temperature;
  final double? humidity;
  final double? ec;
  final double? ph;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;
  final bool modbusOk;
  final int? rssi;
  final DateTime recordedAt;
  final String? note;

  SoilReadingRecord({
    String? clientReadingId,
    required this.farmId,
    this.plotId,
    this.surveyId,
    this.samplingPointId,
    required this.source,
    required this.deviceId,
    this.latitude,
    this.longitude,
    this.moisture,
    this.temperature,
    this.humidity,
    this.ec,
    this.ph,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.modbusOk = true,
    this.rssi,
    required this.recordedAt,
    this.note,
  }) : clientReadingId = clientReadingId ?? const Uuid().v4();

  Map<String, dynamic> toRow() => {
    'client_reading_id': clientReadingId,
    'farm_id': farmId,
    'plot_id': plotId,
    'survey_id': surveyId,
    'sampling_point_id': samplingPointId,
    'source': source == SoilReadingSource.handheld
        ? 'handheld'
        : 'fixed_sensor',
    'device_id': deviceId,
    'latitude': latitude,
    'longitude': longitude,
    'moisture': moisture,
    'temperature': temperature,
    'humidity': humidity,
    'ec': ec,
    'ph': ph,
    'nitrogen': nitrogen,
    'phosphorus': phosphorus,
    'potassium': potassium,
    'modbus_ok': modbusOk,
    'rssi': rssi,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'note': note,
  };

  @override
  List<Object?> get props => [
    clientReadingId,
    farmId,
    plotId,
    surveyId,
    source,
    deviceId,
    recordedAt,
  ];
}
