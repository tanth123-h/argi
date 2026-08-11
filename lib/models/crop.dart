class Crop {
  final String id;
  final String farmId;
  final String name;
  final String variety;
  final DateTime plantedAt;
  final DateTime? expectedHarvest;
  final DateTime? actualHarvest;
  final String status; // growing, harvested, failed
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Crop({
    required this.id,
    required this.farmId,
    required this.name,
    required this.variety,
    required this.plantedAt,
    this.expectedHarvest,
    this.actualHarvest,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'] as String,
      farmId: json['farm_id'] as String,
      name: json['name'] as String,
      variety: json['variety'] as String,
      plantedAt: DateTime.parse(json['planted_at'] as String),
      expectedHarvest: json['expected_harvest'] != null
          ? DateTime.parse(json['expected_harvest'] as String)
          : null,
      actualHarvest: json['actual_harvest'] != null
          ? DateTime.parse(json['actual_harvest'] as String)
          : null,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farm_id': farmId,
      'name': name,
      'variety': variety,
      'planted_at': plantedAt.toIso8601String(),
      'expected_harvest': expectedHarvest?.toIso8601String(),
      'actual_harvest': actualHarvest?.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Crop copyWith({
    String? id,
    String? farmId,
    String? name,
    String? variety,
    DateTime? plantedAt,
    DateTime? expectedHarvest,
    DateTime? actualHarvest,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Crop(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      variety: variety ?? this.variety,
      plantedAt: plantedAt ?? this.plantedAt,
      expectedHarvest: expectedHarvest ?? this.expectedHarvest,
      actualHarvest: actualHarvest ?? this.actualHarvest,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get daysPlanted {
    return DateTime.now().difference(plantedAt).inDays;
  }

  int? get daysUntilHarvest {
    if (expectedHarvest == null) return null;
    return expectedHarvest!.difference(DateTime.now()).inDays;
  }

  bool get isOverdue {
    if (expectedHarvest == null || status != 'growing') return false;
    return DateTime.now().isAfter(expectedHarvest!);
  }
}
