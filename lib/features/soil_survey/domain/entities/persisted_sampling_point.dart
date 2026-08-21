import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'sampling_point.dart';

class PersistedSamplingPoint extends Equatable {
  final String id;
  final String surveyId;
  final String farmId;
  final String samplingKey;
  final int sequence;
  final LatLng location;
  final SamplingPointStatus status;
  final DateTime? sampledAt;

  const PersistedSamplingPoint({
    required this.id,
    required this.surveyId,
    required this.farmId,
    required this.samplingKey,
    required this.sequence,
    required this.location,
    required this.status,
    this.sampledAt,
  });

  @override
  List<Object?> get props => [
    id,
    surveyId,
    farmId,
    samplingKey,
    sequence,
    location,
    status,
    sampledAt,
  ];
}
