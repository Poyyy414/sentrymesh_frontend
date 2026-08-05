import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/location_service.dart';

enum ManeuverType {
  straight,
  slightLeft,
  slightRight,
  left,
  right,
  sharpLeft,
  sharpRight,
  uturn,
  arrive,
}

IconData iconForManeuver(ManeuverType maneuver) {
  switch (maneuver) {
    case ManeuverType.straight:
      return Icons.straight_rounded;
    case ManeuverType.slightLeft:
      return Icons.turn_slight_left_rounded;
    case ManeuverType.slightRight:
      return Icons.turn_slight_right_rounded;
    case ManeuverType.left:
      return Icons.turn_left_rounded;
    case ManeuverType.right:
      return Icons.turn_right_rounded;
    case ManeuverType.sharpLeft:
      return Icons.turn_sharp_left_rounded;
    case ManeuverType.sharpRight:
      return Icons.turn_sharp_right_rounded;
    case ManeuverType.uturn:
      return Icons.u_turn_left_rounded;
    case ManeuverType.arrive:
      return Icons.flag_rounded;
  }
}

String labelForManeuver(ManeuverType maneuver) {
  switch (maneuver) {
    case ManeuverType.straight:
      return 'Continue straight';
    case ManeuverType.slightLeft:
      return 'Slight left';
    case ManeuverType.slightRight:
      return 'Slight right';
    case ManeuverType.left:
      return 'Turn left';
    case ManeuverType.right:
      return 'Turn right';
    case ManeuverType.sharpLeft:
      return 'Sharp left';
    case ManeuverType.sharpRight:
      return 'Sharp right';
    case ManeuverType.uturn:
      return 'Make a U-turn';
    case ManeuverType.arrive:
      return 'You have arrived';
  }
}

/// One leg of a route: the maneuver to make at [point], and the distance
/// walked/driven to reach it from the previous step (or from the route's
/// start, for the first step).
class TurnStep {
  const TurnStep({
    required this.maneuver,
    required this.point,
    required this.legDistanceMeters,
  });

  final ManeuverType maneuver;
  final GeoPoint point;
  final double legDistanceMeters;
}

double _degToRad(double deg) => deg * math.pi / 180;
double _radToDeg(double rad) => rad * 180 / math.pi;

double haversineMeters(GeoPoint a, GeoPoint b) {
  const earthRadiusM = 6371000.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(a.latitude)) *
          math.cos(_degToRad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Shortest distance in meters from [point] to the polyline formed by
/// [waypoints] - used to decide whether a resident has actually drifted off
/// their guided route (worth a reroute) versus still walking along it
/// (not worth hitting the routing backend for). Projects to a local
/// equirectangular plane centered on [point] rather than doing exact
/// geodesic point-to-segment math - segments here span at most a few km,
/// where that approximation's error is well under the drift thresholds
/// this is used for.
double distanceToRouteMeters(GeoPoint point, List<GeoPoint> waypoints) {
  if (waypoints.isEmpty) return double.infinity;
  if (waypoints.length == 1) return haversineMeters(point, waypoints.first);

  const metersPerDegreeLat = 111320.0;
  final cosLat = math.cos(_degToRad(point.latitude));
  double xMeters(GeoPoint p) =>
      (p.longitude - point.longitude) * metersPerDegreeLat * cosLat;
  double yMeters(GeoPoint p) =>
      (p.latitude - point.latitude) * metersPerDegreeLat;

  var minDistance = double.infinity;
  for (var i = 0; i < waypoints.length - 1; i++) {
    final ax = xMeters(waypoints[i]);
    final ay = yMeters(waypoints[i]);
    final bx = xMeters(waypoints[i + 1]);
    final by = yMeters(waypoints[i + 1]);

    final dx = bx - ax;
    final dy = by - ay;
    final lengthSq = dx * dx + dy * dy;
    double distance;
    if (lengthSq == 0) {
      distance = math.sqrt(ax * ax + ay * ay);
    } else {
      final t = (((-ax) * dx + (-ay) * dy) / lengthSq).clamp(0.0, 1.0);
      final closestX = ax + t * dx;
      final closestY = ay + t * dy;
      distance = math.sqrt(closestX * closestX + closestY * closestY);
    }
    if (distance < minDistance) minDistance = distance;
  }
  return minDistance;
}

/// Compass bearing from [a] to [b], in degrees clockwise from north
/// (0-360).
double bearingDegrees(GeoPoint a, GeoPoint b) {
  final lat1 = _degToRad(a.latitude);
  final lat2 = _degToRad(b.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final bearing = _radToDeg(math.atan2(y, x));
  return (bearing + 360) % 360;
}

/// Normalizes a bearing difference to (-180, 180] - positive means turning
/// right (clockwise), negative means turning left.
double _normalizedTurnAngle(double bearingIn, double bearingOut) {
  var delta = bearingOut - bearingIn;
  while (delta > 180) {
    delta -= 360;
  }
  while (delta <= -180) {
    delta += 360;
  }
  return delta;
}

ManeuverType _classifyTurn(double angle) {
  final magnitude = angle.abs();
  if (magnitude < 20) return ManeuverType.straight;
  if (magnitude < 45) {
    return angle > 0 ? ManeuverType.slightRight : ManeuverType.slightLeft;
  }
  if (magnitude < 150) {
    return angle > 0 ? ManeuverType.right : ManeuverType.left;
  }
  if (magnitude < 170) {
    return angle > 0 ? ManeuverType.sharpRight : ManeuverType.sharpLeft;
  }
  return ManeuverType.uturn;
}

/// Turns a raw waypoint polyline into a generic (no street names) list of
/// turn-by-turn steps - no routing-API "steps" data is available from
/// either the OSRM or offline road-network path this app's backend
/// returns, and even OSRM's is requested with steps=false today, so this
/// is derived purely from the geometry already on hand. Works identically
/// whether the route came from a live connection or the tower's fully
/// offline road graph.
///
/// Consecutive points that don't represent a real turn (under ~20 degrees
/// of bearing change) are merged into the same leg so router-graph
/// waypoint noise doesn't produce a "turn" every few meters.
List<TurnStep> computeTurnSteps(List<GeoPoint> waypoints) {
  if (waypoints.length < 2) return const [];

  final steps = <TurnStep>[];
  var legDistance = 0.0;
  var previousBearing = bearingDegrees(waypoints[0], waypoints[1]);

  for (var i = 1; i < waypoints.length - 1; i++) {
    final current = waypoints[i];
    final next = waypoints[i + 1];
    legDistance += haversineMeters(waypoints[i - 1], current);

    final bearingOut = bearingDegrees(current, next);
    final turnAngle = _normalizedTurnAngle(previousBearing, bearingOut);
    final maneuver = _classifyTurn(turnAngle);

    if (maneuver != ManeuverType.straight) {
      steps.add(
        TurnStep(
          maneuver: maneuver,
          point: current,
          legDistanceMeters: legDistance,
        ),
      );
      legDistance = 0.0;
    }
    previousBearing = bearingOut;
  }

  // Final leg into the destination.
  legDistance += haversineMeters(
    waypoints[waypoints.length - 2],
    waypoints.last,
  );
  steps.add(
    TurnStep(
      maneuver: ManeuverType.arrive,
      point: waypoints.last,
      legDistanceMeters: legDistance,
    ),
  );

  return steps;
}
