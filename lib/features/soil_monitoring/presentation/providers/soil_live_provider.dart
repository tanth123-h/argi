import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaona_app/features/soil_monitoring/data/datasources/mqtt_datasource.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/sensor_data.dart';
import 'package:chaona_app/features/soil_monitoring/domain/entities/soil_reading_record.dart';
import 'package:chaona_app/features/soil_monitoring/data/repositories/soil_reading_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── How many history points to keep (2 s per point → 90 = 3 min) ──────────
const _historyMax = 90;
const _offlineAfter = Duration(seconds: 10);

// ── State ──────────────────────────────────────────────────────────────────

enum SoilChartMetric { soil, temperature, humidity, ph }

class SoilLiveState {
  final BrokerStatus broker;
  final DeviceStatus device;
  final SensorData? latest;
  final List<SensorData> history;
  final SoilChartMetric chartMetric;

  const SoilLiveState({
    this.broker = BrokerStatus.connecting,
    this.device = DeviceStatus.unknown,
    this.latest,
    this.history = const [],
    this.chartMetric = SoilChartMetric.soil,
  });

  SoilLiveState copyWith({
    BrokerStatus? broker,
    DeviceStatus? device,
    SensorData? latest,
    List<SensorData>? history,
    SoilChartMetric? chartMetric,
  }) => SoilLiveState(
    broker: broker ?? this.broker,
    device: device ?? this.device,
    latest: latest ?? this.latest,
    history: history ?? this.history,
    chartMetric: chartMetric ?? this.chartMetric,
  );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class SoilLiveNotifier extends Notifier<SoilLiveState> {
  late final MqttDatasource _mqtt;
  late final SoilReadingRepository _readings;
  String? _stationaryFarmId;
  String? _stationaryPlotId;
  StreamSubscription<SensorData>? _dataSub;
  StreamSubscription<BrokerStatus>? _statusSub;
  Timer? _stalenessTimer;
  DateTime? _lastPersistedAt;

  @override
  SoilLiveState build() {
    _mqtt = MqttDatasource();
    _readings = SoilReadingRepository(Supabase.instance.client);

    _dataSub = _mqtt.dataStream.listen(_onData);
    _statusSub = _mqtt.statusStream.listen(
      (s) => state = state.copyWith(broker: s),
    );

    _stalenessTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final last = state.latest;
      if (last == null) return;
      final stale = DateTime.now().difference(last.receivedAt) > _offlineAfter;
      final next = stale ? DeviceStatus.offline : DeviceStatus.online;
      if (next != state.device) state = state.copyWith(device: next);
    });

    ref.onDispose(() {
      _dataSub?.cancel();
      _statusSub?.cancel();
      _stalenessTimer?.cancel();
      _mqtt.dispose();
    });

    Future.microtask(_mqtt.connect);
    return const SoilLiveState();
  }

  void _onData(SensorData data) {
    final history = [...state.history, data];
    if (history.length > _historyMax) {
      history.removeRange(0, history.length - _historyMax);
    }
    state = state.copyWith(
      latest: data,
      history: history,
      device: DeviceStatus.online,
    );
    final farmId = _stationaryFarmId;
    final canPersist =
        _lastPersistedAt == null ||
        DateTime.now().difference(_lastPersistedAt!) >=
            const Duration(seconds: 60);
    if (farmId != null && canPersist) {
      _lastPersistedAt = DateTime.now();
      _readings
          .insert(
            SoilReadingRecord(
              farmId: farmId,
              plotId: _stationaryPlotId,
              source: SoilReadingSource.fixedSensor,
              deviceId: data.device,
              moisture: data.moisture,
              temperature: data.temperature,
              humidity: data.humidity,
              ec: data.ec,
              ph: data.ph,
              nitrogen: data.n,
              phosphorus: data.p,
              potassium: data.k,
              modbusOk: data.modbusOk,
              rssi: data.rssi,
              recordedAt: data.receivedAt,
            ),
          )
          .catchError((_) {});
    }
  }

  void setChartMetric(SoilChartMetric m) =>
      state = state.copyWith(chartMetric: m);

  Future<void> reconnect() => _mqtt.connect();

  void configureStationary({required String farmId, String? plotId}) {
    _stationaryFarmId = farmId;
    _stationaryPlotId = plotId;
    _lastPersistedAt = null;
  }

  void disableStationaryPersistence() {
    _stationaryFarmId = null;
    _stationaryPlotId = null;
  }

  Future<void> saveHandheld({
    required String farmId,
    String? plotId,
    String? surveyId,
    String? samplingPointId,
    required String deviceId,
    required double? latitude,
    required double? longitude,
  }) async {
    final data = state.latest;
    if (data == null) throw StateError('ยังไม่มีข้อมูล ESP32 ล่าสุด');
    await _readings.insert(
      SoilReadingRecord(
        farmId: farmId,
        plotId: plotId,
        surveyId: surveyId,
        samplingPointId: samplingPointId,
        source: SoilReadingSource.handheld,
        deviceId: deviceId,
        latitude: latitude,
        longitude: longitude,
        moisture: data.moisture,
        temperature: data.temperature,
        humidity: data.humidity,
        ec: data.ec,
        ph: data.ph,
        nitrogen: data.n,
        phosphorus: data.p,
        potassium: data.k,
        modbusOk: data.modbusOk,
        rssi: data.rssi,
        recordedAt: DateTime.now(),
      ),
    );
  }
}

final soilLiveProvider = NotifierProvider<SoilLiveNotifier, SoilLiveState>(
  SoilLiveNotifier.new,
);
