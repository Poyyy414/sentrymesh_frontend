import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/services/location_service.dart';
import '../models/route_model.dart';
import '../sources/remote/map_api.dart';

class MapRepository {
  const MapRepository({required MapApi remote}) : _remote = remote;

  final MapApi _remote;

  /// Returns the safest route from [origin] to [destination].
  ///
  /// The backend is asked first. If it returns proper road geometry (more than
  /// the two endpoints) that result is used as-is. Otherwise we fall back to a
  /// road-following route from the OSRM routing service so the line follows
  /// actual streets and the distance/ETA are real instead of a straight line
  /// with a 0-minute estimate.
  Future<RouteModel?> fetchSafeRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    RouteModel? backendRoute;
    try {
      final payload = await _remote.fetchSafeRoute(
        origin: origin,
        destination: destination,
      );
      final route = RouteModel.fromJson(payload);
      if (route.waypoints.isNotEmpty) {
        backendRoute = route;
      }
    } catch (_) {
      backendRoute = null;
    }

    // Backend already gave a real road path — trust it.
    if (backendRoute != null && backendRoute.waypoints.length > 2) {
      return backendRoute;
    }

    // Otherwise compute an accurate road-following route ourselves.
    final roadRoute = await _fetchRoadRoute(
      origin: origin,
      destination: destination,
      riskLevel: backendRoute?.riskLevel,
    );
    if (roadRoute != null) {
      return roadRoute;
    }

    // Last resort: whatever the backend returned (possibly a straight line).
    return backendRoute;
  }

  /// Fetches road-following geometry from the public OSRM routing service.
  Future<RouteModel?> _fetchRoadRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    String? riskLevel,
  }) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final route = routes.first;
      if (route is! Map) return null;

      final geometry = route['geometry'];
      final coordinates = geometry is Map ? geometry['coordinates'] : null;
      if (coordinates is! List || coordinates.length < 2) return null;

      final waypoints = <GeoPoint>[];
      for (final coordinate in coordinates) {
        if (coordinate is List && coordinate.length >= 2) {
          final lon = coordinate[0];
          final lat = coordinate[1];
          if (lon is num && lat is num) {
            waypoints.add(
              GeoPoint(latitude: lat.toDouble(), longitude: lon.toDouble()),
            );
          }
        }
      }
      if (waypoints.length < 2) return null;

      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;
      final minutes = (durationSeconds / 60).round();

      return RouteModel(
        id: 'osrm-road-route',
        label: 'Safest road route',
        distanceKm: distanceMeters / 1000,
        // Never show 0 min for a route that actually has distance.
        estimatedMinutes: minutes < 1 && distanceMeters > 0 ? 1 : minutes,
        riskLevel: (riskLevel == null || riskLevel.isEmpty || riskLevel == 'Unknown')
            ? 'Safe'
            : riskLevel,
        waypoints: waypoints,
      );
    } catch (_) {
      return null;
    }
  }
}
