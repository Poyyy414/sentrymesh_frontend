import 'route_model.dart';

class RescueNavigationModel {
  const RescueNavigationModel({
    required this.directDistanceKm,
    required this.bearingDegrees,
    required this.route,
    this.navigationUrl,
    this.raw = const {},
  });

  final double directDistanceKm;
  final double bearingDegrees;
  final RouteModel? route;
  final String? navigationUrl;
  final Map<String, Object?> raw;

  factory RescueNavigationModel.fromJson(Map<String, Object?> json) {
    final rawRoute = json['route'];
    final route = rawRoute is Map<String, Object?>
        ? RouteModel.fromJson(rawRoute)
        : rawRoute is Map
        ? RouteModel.fromJson(
            rawRoute.map((key, value) => MapEntry(key.toString(), value)),
          )
        : null;

    return RescueNavigationModel(
      directDistanceKm: _asDouble(
        json['direct_distance_km'] ?? json['distance_km'],
      ),
      bearingDegrees: _asDouble(json['bearing_degrees'] ?? json['bearing']),
      route: route,
      navigationUrl: json['navigation_url']?.toString(),
      raw: json,
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
