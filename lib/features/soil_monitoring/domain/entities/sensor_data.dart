/// Live sensor entity — data from Arduino UNO R4 WiFi via MQTT
class SensorData {
  final String device;
  final int soil; // soil moisture %
  final double temperature; // °C  — from Modbus register 1
  final double humidity; // %   — from Modbus register 0
  final double ph;
  final double n; // mg/kg
  final double p; // mg/kg
  final double k; // mg/kg
  final bool modbusOk;
  final int? rssi; // Arduino WiFi signal dBm
  final DateTime receivedAt;

  const SensorData({
    required this.device,
    required this.soil,
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.n,
    required this.p,
    required this.k,
    required this.modbusOk,
    required this.receivedAt,
    this.rssi,
  });
}

/// App ↔ MQTT broker connection state
enum BrokerStatus { connecting, connected, disconnected }

/// Arduino device liveness (based on message freshness)
enum DeviceStatus { unknown, online, offline }
