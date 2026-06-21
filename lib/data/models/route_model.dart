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
        ? rawWaypoints
              .map(_mapFrom)
              .where((point) => point.isNotEmpty)
              .map(_pointFromJson)
              .toList()
        : <GeoPoint>[];

    final distanceKm = _asDouble(json['distance_km'] ?? json['distanceKm']);
    final rawMinutes =
        int.tryParse(
          (json['estimated_minutes'] ?? json['estimatedMinutes'])?.toString() ??
              '',
        ) ??
        0;

    return RouteModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      distanceKm: distanceKm,
      // Never show 0 min for a route that actually has distance. When the
      // backend omits/zeroes the ETA, estimate from distance (~30 km/h urban),
      // flooring at 1 min so the metric is never misleadingly blank.
      estimatedMinutes: rawMinutes < 1 && distanceKm > 0
          ? (distanceKm / 30 * 60).round().clamp(1, 1 << 31)
          : rawMinutes,
      riskLevel:
          json['risk_level']?.toString() ??
          json['riskLevel']?.toString() ??
          'Unknown',
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
      latitude: _asDouble(json['latitude'] ?? json['lat']),
      longitude: _asDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, Object?> _mapFrom(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const {};
  }
}
