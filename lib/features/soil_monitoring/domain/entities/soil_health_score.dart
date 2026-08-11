import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:chaona_app/app/theme.dart';

enum SoilHealthScoreBand { good, moderate, poor }

class SoilHealthScore extends Equatable {
  final double composite;
  final double moistureScore;
  final double nScore;
  final double pScore;
  final double kScore;

  const SoilHealthScore({
    required this.composite,
    required this.moistureScore,
    required this.nScore,
    required this.pScore,
    required this.kScore,
  });

  SoilHealthScoreBand get band {
    if (composite >= 70) return SoilHealthScoreBand.good;
    if (composite >= 40) return SoilHealthScoreBand.moderate;
    return SoilHealthScoreBand.poor;
  }

  Color get color {
    switch (band) {
      case SoilHealthScoreBand.good:
        return AppTheme.statusGood;
      case SoilHealthScoreBand.moderate:
        return AppTheme.statusModerate;
      case SoilHealthScoreBand.poor:
        return AppTheme.statusPoor;
    }
  }

  String get labelThai {
    switch (band) {
      case SoilHealthScoreBand.good:
        return 'สมบูรณ์ดี';
      case SoilHealthScoreBand.moderate:
        return 'ปานกลาง';
      case SoilHealthScoreBand.poor:
        return 'ต้องดูแล';
    }
  }

  @override
  List<Object?> get props => [composite, moistureScore, nScore, pScore, kScore];
}
