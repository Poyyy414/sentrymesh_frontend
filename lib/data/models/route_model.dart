import '../../core/services/location_service.dart';

class RouteModel {
  const RouteModel({
    required this.id,
    required this.label,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.riskLevel,
    required this.waypoints,
  });

  final String id;
  final String label;
  final double distanceKm;
  final int estimatedMinutes;
  final String riskLevel;
  final List<GeoPoint> waypoints;

  factory RouteModel.fromJson(Map<String, Object?> json) {
    final rawWaypoints = json['waypoints'];
    final waypoints = rawWaypoints is List
        ? rawWaypoints.whereType<Map<String, Object?>>().map(_pointFromJson).toList()
        : <GeoPoint>[];

    return RouteModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      distanceKm: _asDouble(json['distance_km']),
      estimatedMinutes: int.tryParse(json['estimated_minutes']?.toString() ?? '') ?? 0,
      riskLevel: json['risk_level']?.toString() ?? 'Unknown',
      waypoints: waypoints,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'distance_km': distanceKm,
      'estimated_minutes': estimatedMinutes,
      'risk_level': riskLevel,
      'waypoints': waypoints.map((point) => point.toJson()).toList(),
    };
  }

  static GeoPoint _pointFromJson(Map<String, Object?> json) {
    return GeoPoint(
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
