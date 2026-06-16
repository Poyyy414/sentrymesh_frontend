import '../../shared/enums/hazard_type.dart';
import '../../shared/enums/rescue_status.dart';

class RescueRequestModel {
  const RescueRequestModel({
    required this.id,
    required this.emergencyType,
    required this.peopleNeedingHelp,
    required this.description,
    required this.status,
    required this.createdAt,
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.assignedShelterId,
    this.assignedShelterName,
    this.assignedShelterAddress,
  });

  final String id;
  final HazardType emergencyType;
  final int peopleNeedingHelp;
  final String description;
  final RescueStatus status;
  final DateTime createdAt;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final String? assignedShelterId;
  final String? assignedShelterName;
  final String? assignedShelterAddress;

  factory RescueRequestModel.fromJson(Map<String, Object?> json) {
    return RescueRequestModel(
      id: json['id']?.toString() ?? '',
      emergencyType: HazardType.values.firstWhere(
        (type) => type.name == json['emergency_type']?.toString(),
        orElse: () => HazardType.distress,
      ),
      peopleNeedingHelp:
          int.tryParse(json['people_needing_help']?.toString() ?? '') ?? 1,
      description: json['description']?.toString() ?? '',
      status: RescueStatus.values.firstWhere(
        (status) => status.name == json['status']?.toString(),
        orElse: () => RescueStatus.pending,
      ),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      photoUrl: json['photo_url']?.toString(),
      latitude: _doubleFrom(json['latitude'] ?? json['lat']),
      longitude: _doubleFrom(json['longitude'] ?? json['lng'] ?? json['lon']),
      locationLabel:
          json['location_label']?.toString() ??
          json['locationLabel']?.toString(),
      assignedShelterId: json['assigned_shelter_id']?.toString(),
      assignedShelterName: json['assigned_shelter_name']?.toString(),
      assignedShelterAddress: json['assigned_shelter_address']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'emergency_type': emergencyType.name,
      'people_needing_help': peopleNeedingHelp,
      'description': description,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'photo_url': photoUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationLabel != null) 'location_label': locationLabel,
    };
  }

  Map<String, Object?> toCreateJson() {
    return {
      'emergency_type': emergencyType.name,
      'people_needing_help': peopleNeedingHelp,
      'description': description,
      'status': status.name,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationLabel != null) 'location_label': locationLabel,
    };
  }

  static double? _doubleFrom(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}
