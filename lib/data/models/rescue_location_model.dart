import '../../core/services/location_service.dart';

class RescueLocationModel {
  const RescueLocationModel({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.locationLabel,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? locationLabel;
  final DateTime? recordedAt;

  GeoPoint get point {
    return GeoPoint(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
    );
  }

  factory RescueLocationModel.fromPoint(
    GeoPoint point, {
    String? locationLabel,
    DateTime? recordedAt,
  }) {
    return RescueLocationModel(
      latitude: point.latitude,
      longitude: point.longitude,
      accuracyMeters: point.accuracyMeters,
      locationLabel: locationLabel,
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
    );
  }

  factory RescueLocationModel.fromJson(Map<String, Object?> json) {
    return RescueLocationModel(
      latitude: _asDouble(json['latitude'] ?? json['lat']),
      longitude: _asDouble(json['longitude'] ?? json['lng'] ?? json['lon']),
      accuracyMeters: _asNullableDouble(
        json['accuracy_m'] ??
            json['accuracyMeters'] ??
            json['location_accuracy_meters'],
      ),
      locationLabel: json['location_label']?.toString(),
      recordedAt: DateTime.tryParse(
        (json['recorded_at'] ??
                    json['location_updated_at'] ??
                    json['updated_at'] ??
                    json['timestamp'])
                ?.toString() ??
            '',
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracy_m': accuracyMeters,
      if (locationLabel != null) 'location_label': locationLabel,
      'recorded_at': (recordedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
  }

  static double _asDouble(Object? value) {
    return _asNullableDouble(value) ?? 0;
  }

  static double? _asNullableDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}
