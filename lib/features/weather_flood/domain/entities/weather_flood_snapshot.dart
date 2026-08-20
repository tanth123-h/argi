import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum FloodStatus { observed, noObservedFeature, unavailable }

enum DroughtStatus { soilStress, watch, noStress, unavailable }

class WeatherForecastDay {
  final DateTime date;
  final double maxC;
  final double minC;
  final double rainMm;
  final int rainProbability;
  final double windKmh;
  const WeatherForecastDay({required this.date, required this.maxC, required this.minC, required this.rainMm, required this.rainProbability, required this.windKmh});
}

class WeatherFloodSnapshot extends Equatable {
  final double temperatureC;
  final double rainMm;
  final int rainProbability24h;
  final String weatherLabel;
  final FloodStatus floodStatus;
  final String floodDetail;
  final DroughtStatus droughtStatus;
  final String droughtDetail;
  final double? soilMoisture;
  final DateTime fetchedAt;
  final Uri weatherSource;
  final Uri floodSource;
  final List<LatLng> floodPoints;
  final double windKmh;
  final String windDirection;
  final double windDirectionDegrees;
  final List<WeatherForecastDay> forecast;

  const WeatherFloodSnapshot({
    required this.temperatureC,
    required this.rainMm,
    required this.rainProbability24h,
    required this.weatherLabel,
    required this.floodStatus,
    required this.floodDetail,
    required this.droughtStatus,
    required this.droughtDetail,
    this.soilMoisture,
    required this.fetchedAt,
    required this.weatherSource,
    required this.floodSource,
    this.floodPoints = const [],
    this.windKmh = 0,
    this.windDirection = '-',
    this.windDirectionDegrees = 0,
    this.forecast = const [],
  });

  @override
  List<Object?> get props => [
    temperatureC,
    rainMm,
    rainProbability24h,
    weatherLabel,
    floodStatus,
    floodDetail,
    droughtStatus,
    droughtDetail,
    soilMoisture,
    fetchedAt,
    floodPoints,
    windKmh,
    windDirection,
    windDirectionDegrees,
    forecast,
  ];
}
