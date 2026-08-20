import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../domain/entities/weather_flood_snapshot.dart';

class WeatherFloodService {
  final http.Client client;
  WeatherFloodService({http.Client? client}) : client = client ?? http.Client();

  void dispose() => client.close();

  static const _weatherBase = 'https://api.open-meteo.com/v1/forecast';
  static const _floodSource =
      'https://gistdaportal.gistda.or.th/arcgis/rest/services/Hosted/GISTDA_FLOOD/FeatureServer/0/query';

  Future<WeatherFloodSnapshot> fetch(
    LatLng location, {
    double? soilMoisture,
  }) async {
    final weatherUri = Uri.parse(_weatherBase).replace(
      queryParameters: {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'current': 'temperature_2m,precipitation,rain,weather_code,wind_speed_10m,wind_direction_10m',
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,weather_code',
        'hourly': 'precipitation_probability,precipitation',
        'forecast_days': '7',
        'timezone': 'Asia/Bangkok',
      },
    );
    final weatherResponse = await client
        .get(weatherUri)
        .timeout(const Duration(seconds: 12));
    if (weatherResponse.statusCode != 200)
      throw StateError('weather_http_${weatherResponse.statusCode}');
    final weather = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
    final current = Map<String, dynamic>.from(weather['current'] as Map);
    final hourly = Map<String, dynamic>.from(weather['hourly'] as Map);
    final daily = Map<String, dynamic>.from(weather['daily'] as Map);
    final rainProbability = maxRainProbabilityNext24(hourly);
    final rain =
        (current['rain'] as num?)?.toDouble() ??
        (current['precipitation'] as num?)?.toDouble() ??
        0;
    final flood = await _fetchFlood(location);
    final drought = _droughtStatus(
      soilMoisture: soilMoisture,
      rainProbability: rainProbability,
    );
    return WeatherFloodSnapshot(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      rainMm: rain,
      rainProbability24h: rainProbability,
      weatherLabel: _weatherLabel((current['weather_code'] as num?)?.toInt()),
      floodStatus: flood.$1,
      floodDetail: flood.$2,
      droughtStatus: drought.$1,
      droughtDetail: drought.$2,
      soilMoisture: soilMoisture,
      fetchedAt: DateTime.now(),
      weatherSource: weatherUri,
      floodSource: Uri.parse(_floodSource),
      floodPoints: flood.$3,
      windKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      windDirection: _direction((current['wind_direction_10m'] as num?)?.toDouble()),
      windDirectionDegrees: (current['wind_direction_10m'] as num?)?.toDouble() ?? 0,
      forecast: _forecast(daily),
    );
  }

  List<WeatherForecastDay> _forecast(Map<String, dynamic> daily) {
    final dates = daily['time'];
    final max = daily['temperature_2m_max'];
    final min = daily['temperature_2m_min'];
    final rain = daily['precipitation_sum'];
    final probability = daily['precipitation_probability_max'];
    final wind = daily['wind_speed_10m_max'];
    if (dates is! List || max is! List || min is! List) return const [];
    return [
      for (var i = 0; i < dates.length && i < max.length && i < min.length; i++)
        if (DateTime.tryParse(dates[i].toString()) != null)
          WeatherForecastDay(
            date: DateTime.parse(dates[i].toString()),
            maxC: (max[i] as num?)?.toDouble() ?? 0,
            minC: (min[i] as num?)?.toDouble() ?? 0,
            rainMm: i < (rain is List ? rain.length : 0) ? ((rain[i] as num?)?.toDouble() ?? 0) : 0,
            rainProbability: i < (probability is List ? probability.length : 0) ? ((probability[i] as num?)?.toInt() ?? 0) : 0,
            windKmh: i < (wind is List ? wind.length : 0) ? ((wind[i] as num?)?.toDouble() ?? 0) : 0,
          ),
    ];
  }

  String _direction(double? degrees) {
    if (degrees == null) return '-';
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return names[((degrees + 22.5) ~/ 45) % 8];
  }

  (DroughtStatus, String) _droughtStatus({
    required double? soilMoisture,
    required int rainProbability,
  }) {
    if (soilMoisture == null) {
      return (
        DroughtStatus.watch,
        rainProbability < 20
            ? 'ยังไม่มีเซนเซอร์ยืนยัน แต่พยากรณ์ฝนน้อย จึงควรเฝ้าระวังการขาดน้ำ'
            : 'ยังไม่มีเซนเซอร์ยืนยัน แม้พยากรณ์มีฝน จึงยังสรุปภาวะแล้งไม่ได้',
      );
    }
    if (soilMoisture < 20)
      return (
        DroughtStatus.soilStress,
        'ความชื้นดินต่ำกว่า 20% ควรตรวจระบบน้ำและพืชทันที',
      );
    if (soilMoisture < 30 || rainProbability < 20)
      return (
        DroughtStatus.watch,
        'ควรติดตามความชื้นดินและวางแผนให้น้ำตามชนิดพืช',
      );
    return (
      DroughtStatus.noStress,
      'ยังไม่พบสัญญาณขาดน้ำจากค่าความชื้นดินล่าสุด',
    );
  }

  Future<(FloodStatus, String, List<LatLng>)> _fetchFlood(LatLng location) async {
    final uri = Uri.parse(_floodSource).replace(
      queryParameters: {
        'f': 'json',
        'where': '1=1',
        'geometry': '${location.longitude},${location.latitude}',
        'geometryType': 'esriGeometryPoint',
        'inSR': '4326',
        'spatialRel': 'esriSpatialRelIntersects',
        'distance': '5000',
        'units': 'esriSRUnit_Meter',
        'outFields': '*',
        'returnGeometry': 'true',
      },
    );
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200)
        return (FloodStatus.unavailable, 'GISTDA ตอบกลับ HTTP ${response.statusCode}', const <LatLng>[]);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['error'] != null)
        return (FloodStatus.unavailable, 'GISTDA ไม่สามารถอ่านข้อมูลได้', const <LatLng>[]);
      final features = body['features'];
      final points = <LatLng>[];
      if (features is List) {
        for (final feature in features.whereType<Map>()) {
          final geometry = feature['geometry'];
          if (geometry is Map && geometry['x'] is num && geometry['y'] is num) {
            points.add(LatLng((geometry['y'] as num).toDouble(), (geometry['x'] as num).toDouble()));
          }
        }
        if (features.isNotEmpty) return (FloodStatus.observed, 'พบข้อมูลพื้นที่น้ำท่วม ${features.length} จุด/พื้นที่ในรัศมีประมาณ 5 กิโลเมตร', points);
      }
      return (
        FloodStatus.noObservedFeature,
        'ยังไม่พบพื้นที่น้ำท่วมในข้อมูลล่าสุดใกล้ฟาร์ม',
        const <LatLng>[],
      );
    } catch (_) {
      return (FloodStatus.unavailable, 'เชื่อมต่อข้อมูลน้ำท่วมไม่ได้', const <LatLng>[]);
    }
  }

  String _weatherLabel(int? code) => switch (code) {
    0 => 'ท้องฟ้าแจ่มใส',
    1 || 2 || 3 => 'มีเมฆบางส่วนถึงมาก',
    51 || 53 || 55 || 61 || 63 || 65 || 80 || 81 || 82 => 'มีฝนหรือฝนปรอย',
    95 || 96 || 99 => 'มีโอกาสพายุฝนฟ้าคะนอง',
    _ => 'สภาพอากาศไม่ทราบแน่ชัด',
  };
}

int maxRainProbabilityNext24(Map<String, dynamic> hourly, {DateTime? now}) {
  final times = hourly['time'];
  final values = hourly['precipitation_probability'];
  if (times is! List || values is! List) return 0;
  final start = now ?? DateTime.now();
  final end = start.add(const Duration(hours: 24));
  var maximum = 0;
  for (var index = 0; index < times.length && index < values.length; index++) {
    final time = DateTime.tryParse(times[index].toString());
    final value = values[index];
    if (time == null || value is! num) continue;
    if (time.isBefore(start) || !time.isBefore(end)) continue;
    if (value.toInt() > maximum) maximum = value.toInt();
  }
  return maximum;
}
