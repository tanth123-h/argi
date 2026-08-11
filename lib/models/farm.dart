class Farm {
  final String id;
  final String userId;
  final String name;
  final String location;
  final double size;
  final List<Map<String, double>>? polygonCoordinates;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Farm({
    required this.id,
    required this.userId,
    required this.name,
    required this.location,
    required this.size,
    this.polygonCoordinates,
    required this.createdAt,
    this.updatedAt,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    List<Map<String, double>>? coordinates;
    if (json['polygon_coordinates'] != null) {
      coordinates = (json['polygon_coordinates'] as List)
          .map(
            (coord) => {
              'lat': (coord['lat'] as num).toDouble(),
              'lng': (coord['lng'] as num).toDouble(),
            },
          )
          .toList();
    }

    return Farm(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      size: (json['size'] as num).toDouble(),
      polygonCoordinates: coordinates,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'location': location,
      'size': size,
      'polygon_coordinates': polygonCoordinates,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Farm copyWith({
    String? id,
    String? userId,
    String? name,
    String? location,
    double? size,
    List<Map<String, double>>? polygonCoordinates,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Farm(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      location: location ?? this.location,
      size: size ?? this.size,
      polygonCoordinates: polygonCoordinates ?? this.polygonCoordinates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
