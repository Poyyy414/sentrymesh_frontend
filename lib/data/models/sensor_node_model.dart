import '../../core/services/location_service.dart';

class SensorNodeModel {
  const SensorNodeModel({
    required this.id,
    required this.location,
    required this.batteryPercent,
    required this.lastSeenAt,
    this.waterLevelMeters,
    this.soilMoisture,
    this.signalStrength,
  });

  final String id;
  final GeoPoint location;
  final int batteryPercent;
  final DateTime lastSeenAt;
  final double? waterLevelMeters;
  final double? soilMoisture;
  final double? signalStrength;

  factory SensorNodeModel.fromJson(Map<String, Object?> json) {
    return SensorNodeModel(
      id: json['id']?.toString() ?? '',
      location: GeoPoint(
        latitude: _asDouble(json['latitude']),
        longitude: _asDouble(json['longitude']),
      ),
      batteryPercent: int.tryParse(json['battery_percent']?.toString() ?? '') ?? 0,
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? '') ?? DateTime.now(),
      waterLevelMeters: _nullableDouble(json['water_level_meters']),
      soilMoisture: _nullableDouble(json['soil_moisture']),
      signalStrength: _nullableDouble(json['signal_strength']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'battery_percent': batteryPercent,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'water_level_meters': waterLevelMeters,
      'soil_moisture': soilMoisture,
      'signal_strength': signalStrength,
    };
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    return _asDouble(value);
  }
}
