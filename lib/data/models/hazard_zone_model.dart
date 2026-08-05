/// A monitored evacuation center currently flagged at HIGH/CRITICAL flood
/// risk — parsed from the `hazard:warning` socket event's actual payload
/// shape (`{alert_level, alert, center: {id, latitude, longitude, name}}`),
/// not a multi-point grid.
class HazardZone {
  const HazardZone({
    required this.centerId,
    required this.centerName,
    required this.alertLevel,
    required this.latitude,
    required this.longitude,
  });

  final String centerId;
  final String centerName;
  final String alertLevel;
  final double latitude;
  final double longitude;

  static HazardZone? fromSocketPayload(Map<String, Object?> data) {
    final center = data['center'];
    if (center is! Map) return null;
    final centerMap = Map<String, Object?>.from(center);

    final id = centerMap['id']?.toString();
    final lat = _asDouble(centerMap['latitude']);
    final lon = _asDouble(centerMap['longitude']);
    if (id == null || lat == null || lon == null) return null;

    return HazardZone(
      centerId: id,
      centerName: centerMap['name']?.toString() ?? 'Monitored area',
      alertLevel: data['alert_level']?.toString() ?? 'HIGH',
      latitude: lat,
      longitude: lon,
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
