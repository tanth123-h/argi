import 'package:equatable/equatable.dart';

enum SamplingPointStatus { pending, sampled, skipped }

class SamplingPoint extends Equatable {
  final String id;
  final String plotId;
  final int sequence;
  final double latitude;
  final double longitude;
  final SamplingPointStatus status;

  const SamplingPoint({
    required this.id,
    required this.plotId,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    this.status = SamplingPointStatus.pending,
  });

  SamplingPoint copyWith({SamplingPointStatus? status}) => SamplingPoint(
        id: id,
        plotId: plotId,
        sequence: sequence,
        latitude: latitude,
        longitude: longitude,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [id, plotId, sequence, latitude, longitude, status];
}
