enum SoilReadingSource { handheld, fixedSensor, demo }

class SoilReadingRecord {
  final String farmId;
  final String? plotId;
  final String? surveyId;
  final String? samplingPointId;
  final SoilReadingSource source;
  final String deviceId;
  final double? latitude;
  final double? longitude;
  final double moisture;
  final double temperature;
  final double humidity;
  final double ec;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final bool modbusOk;
  final int? rssi;
  final DateTime recordedAt;

  const SoilReadingRecord({
    required this.farmId,
    required this.source,
    required this.deviceId,
    required this.moisture,
    required this.temperature,
    required this.humidity,
    required this.ec,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.modbusOk,
    required this.recordedAt,
    this.plotId,
    this.surveyId,
    this.samplingPointId,
    this.latitude,
    this.longitude,
    this.rssi,
  });

  Map<String, dynamic> toMap() => {
    'farm_id': farmId,
    'plot_id': plotId,
    'survey_id': surveyId,
    'sampling_point_id': samplingPointId,
    'source': source.name,
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
    'recorded_at': recordedAt.toIso8601String(),
  };
}
