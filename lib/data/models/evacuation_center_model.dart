class EvacuationCenterModel {
  const EvacuationCenterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.capacity,
    required this.currentOccupancy,
    required this.availableSlots,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  final String id;
  final String name;
  final String address;
  final int capacity;
  final int currentOccupancy;
  final int availableSlots;
  final double latitude;
  final double longitude;
  final String status;

  bool get isOpen => status == 'open';

  factory EvacuationCenterModel.fromJson(Map<String, Object?> json) {
    return EvacuationCenterModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      capacity: _asInt(json['capacity']),
      currentOccupancy: _asInt(json['current_occupancy']),
      availableSlots: _asInt(json['available_slots']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      status: json['status']?.toString() ?? 'open',
    );
  }

  static int _asInt(Object? v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
