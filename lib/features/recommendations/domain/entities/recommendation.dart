import 'package:equatable/equatable.dart';
import 'risk_level.dart';
import 'source_reference.dart';

class Recommendation extends Equatable {
  final String id;
  final String title;
  final String action;
  final RiskLevel level;
  final String value;
  final String calculation;
  final double confidence;
  final SourceReference source;
  final DateTime createdAt;

  const Recommendation({
    required this.id,
    required this.title,
    required this.action,
    required this.level,
    required this.value,
    required this.calculation,
    required this.confidence,
    required this.source,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        action,
        level,
        value,
        calculation,
        confidence,
        source,
        createdAt,
      ];
}
