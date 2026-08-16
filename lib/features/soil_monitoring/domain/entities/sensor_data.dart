/// Live sensor entity: normalized readings from an ESP32 sensor.
class SensorData {
  final String device;
  final double moisture;
  final double temperature;
  final double humidity;
  final double ec;
  final double ph;
  final double n;
  final double p;
  final double k;
  final bool modbusOk;
  final int? rssi;
  final DateTime receivedAt;

  const SensorData({
    required this.device,
    required this.moisture,
    required this.temperature,
    required this.humidity,
    required this.ec,
    required this.ph,
    required this.n,
    required this.p,
    required this.k,
    required this.modbusOk,
    required this.receivedAt,
    this.rssi,
  });

  double get soil => moisture;
}

enum BrokerStatus { connecting, connected, disconnected }

enum DeviceStatus { unknown, online, offline }
