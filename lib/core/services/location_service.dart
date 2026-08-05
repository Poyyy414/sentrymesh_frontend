import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.heading,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  // Course-over-ground in degrees (0 = north), and current speed - both
  // straight from the platform's Position. Heading is only meaningful
  // while actually moving (GPS derives it from successive fixes, not a
  // compass), so callers should gate on speed before rotating anything
  // to it - see kMovingSpeedThresholdMps in map_view.dart.
  final double? heading;
  final double? speedMps;

  Map<String, Object?> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracy_m': accuracyMeters,
    };
  }
}

class LocationService {
  const LocationService();

  Future<void> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedException();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }
  }

  Future<GeoPoint> currentLocation() async {
    await _ensureLocationAccess();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 30),
        ),
      );

      return _toGeoPoint(position);
    } on TimeoutException {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return _toGeoPoint(lastKnownPosition);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      return _toGeoPoint(position);
    } catch (_) {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return _toGeoPoint(lastKnownPosition);
      }

      rethrow;
    }
  }

  Stream<GeoPoint> watchLocation() async* {
    await _ensureLocationAccess();

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map(_toGeoPoint);
  }

  GeoPoint _toGeoPoint(Position position) {
    return GeoPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      heading: position.heading,
      speedMps: position.speed,
    );
  }

  Future<void> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() {
    return Geolocator.openAppSettings();
  }
}

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();
}

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();
}

class LocationPermissionPermanentlyDeniedException implements Exception {
  const LocationPermissionPermanentlyDeniedException();
}
