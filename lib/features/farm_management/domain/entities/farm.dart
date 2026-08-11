import 'package:equatable/equatable.dart';
import 'plot.dart';

class Farm extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? location;
  final double areaRai;
  final String cropType;
  final DateTime createdAt;
  final List<Plot> plots;

  const Farm({
    required this.id,
    required this.userId,
    required this.name,
    this.location,
    required this.areaRai,
    required this.cropType,
    required this.createdAt,
    this.plots = const [],
  });

  @override
  List<Object?> get props => [id, userId, name];
}
