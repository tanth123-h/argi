import 'package:equatable/equatable.dart';

enum SoilSurveyStatus { inProgress, completed, cancelled }

class SoilSurvey extends Equatable {
  final String id;
  final String farmId;
  final SoilSurveyStatus status;
  final int pointCount;
  final DateTime startedAt;
  final DateTime? completedAt;

  const SoilSurvey({
    required this.id,
    required this.farmId,
    required this.status,
    required this.pointCount,
    required this.startedAt,
    this.completedAt,
  });

  @override
  List<Object?> get props => [
    id,
    farmId,
    status,
    pointCount,
    startedAt,
    completedAt,
  ];
}
