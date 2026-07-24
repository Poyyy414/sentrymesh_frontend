import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'location_service.dart';

// Fallback map center used whenever a real location (device GPS, resident,
// responder) isn't available yet — this deployment's operating area
// (Naga/Calabanga, Camarines Sur). Was previously copy-pasted as a raw
// coordinate literal in six-plus places; kept here as the one place to
// update if the deployment region ever changes. Exposed as separate double
// constants too since Dart's const evaluator won't allow `.latitude` field
// access on a const GeoPoint from other files.
const kDefaultLatitude = 13.6218;
const kDefaultLongitude = 123.1948;
const kDefaultMapCenter = GeoPoint(
  latitude: kDefaultLatitude,
  longitude: kDefaultLongitude,
);

/// A rectangular bounding box roughly [radiusKm] around [center] in every
/// direction, for area-based offline downloads (2D tiles, 3D packs).
LatLngBounds boundsAroundCenter(GeoPoint center, double radiusKm) {
  final latDelta = radiusKm / 111.0;
  final lonDelta =
      radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));
  return LatLngBounds(
    LatLng(center.latitude - latDelta, center.longitude - lonDelta),
    LatLng(center.latitude + latDelta, center.longitude + lonDelta),
  );
}
