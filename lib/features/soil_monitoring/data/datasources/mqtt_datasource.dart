import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:chaona_app/core/constants/app_constants.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/sensor_data.dart';

/// MQTT datasource — connects to broker.emqx.io and subscribes to
/// [AppConstants.mqttTopic] (farm/uno_r4/sensors).
///
/// Data source: Arduino UNO R4 WiFi + 7-in-1 Modbus NPK soil sensor
/// Hardware: RS485 → Modbus → UNO R4 WiFi → MQTT (broker.emqx.io)
/// Protocol: MQTT 3.1.1 / JSON payload, published every 2 seconds
class MqttDatasource {
  MqttServerClient? _client;

  final _dataController = StreamController<SensorData>.broadcast();
  final _statusController = StreamController<BrokerStatus>.broadcast();

  Stream<SensorData> get dataStream => _dataController.stream;
  Stream<BrokerStatus> get statusStream => _statusController.stream;

  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _disposed = false;

  Future<void> connect() async {
    if (_disposed) return;
    _statusController.add(BrokerStatus.connecting);

    final clientId =
        '${AppConstants.mqttClientId}_${Random().nextInt(0xFFFFFF)}';

    final client = MqttServerClient(AppConstants.mqttBroker, clientId)
      ..port = AppConstants.mqttPort
      ..keepAlivePeriod = 20
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false);

    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onAutoReconnect = () =>
        _statusController.add(BrokerStatus.connecting);
    client.onAutoReconnected = _onConnected;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();

    _client = client;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('[MQTT] connect failed: $e');
      client.disconnect();
      _scheduleRetry();
      return;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      _scheduleRetry();
      return;
    }

    _retryAttempt = 0;
    client.subscribe(AppConstants.mqttTopic, MqttQos.atLeastOnce);
    client.updates?.listen(
      _onMessage,
      onError: (Object e) => debugPrint('[MQTT] stream error: $e'),
    );
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>> events) {
    for (final event in events) {
      final message = event.payload;
      if (message is! MqttPublishMessage) continue;
      final raw = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      );
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _dataController.add(_parse(json));
      } catch (e) {
        debugPrint('[MQTT] bad payload ignored: $e\n$raw');
      }
    }
  }

  SensorData _parse(Map<String, dynamic> j) {
    num asNum(dynamic v) => v is num ? v : 0;
    return SensorData(
      device: j['device']?.toString() ?? 'UNO_R4',
      soil: asNum(j['soil']).toInt(),
      temperature: asNum(j['temperature']).toDouble(),
      humidity: asNum(j['humidity']).toDouble(),
      ph: asNum(j['ph']).toDouble(),
      n: asNum(j['n']).toDouble(),
      p: asNum(j['p']).toDouble(),
      k: asNum(j['k']).toDouble(),
      modbusOk: j['modbus_ok'] == true,
      rssi: j['rssi'] is num ? (j['rssi'] as num).toInt() : null,
      receivedAt: DateTime.now(),
    );
  }

  void _onConnected() {
    _retryAttempt = 0;
    if (!_disposed) _statusController.add(BrokerStatus.connected);
  }

  void _onDisconnected() {
    if (_disposed) return;
    _statusController.add(BrokerStatus.disconnected);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer?.cancel();
    final delay = Duration(seconds: min(30, 2 << min(_retryAttempt, 4)));
    _retryAttempt++;
    debugPrint('[MQTT] retry in ${delay.inSeconds}s');
    _retryTimer = Timer(delay, () {
      final state = _client?.connectionStatus?.state;
      if (state != MqttConnectionState.connected &&
          state != MqttConnectionState.connecting) {
        connect();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _client?.disconnect();
    _dataController.close();
    _statusController.close();
  }
}
