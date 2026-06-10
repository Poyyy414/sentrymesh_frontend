import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
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
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return GeoPoint(
          latitude: lastKnownPosition.latitude,
          longitude: lastKnownPosition.longitude,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 25),
        ),
      );

      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      final lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        return GeoPoint(
          latitude: lastKnownPosition.latitude,
          longitude: lastKnownPosition.longitude,
        );
      }

      rethrow;
    }
  }

  Stream<GeoPoint> watchLocation() async* {
    await _ensureLocationAccess();

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10,
      ),
    ).map(
      (position) =>
          GeoPoint(latitude: position.latitude, longitude: position.longitude),
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
