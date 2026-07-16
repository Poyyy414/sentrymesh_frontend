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
    this.nearestEvacuationName,
    this.nearestEvacuationLat,
    this.nearestEvacuationLng,
    this.nearestEvacuationDistanceKm,
    this.assignedTeamId,
    this.assignedTeamName,
    this.assignedAt,
    this.riskLevel,
    this.priorityScore,
    this.priorityRank,
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
  final String? nearestEvacuationName;
  final double? nearestEvacuationLat;
  final double? nearestEvacuationLng;
  final double? nearestEvacuationDistanceKm;
  final String? assignedTeamId;
  final String? assignedTeamName;
  final DateTime? assignedAt;
  final String? riskLevel;
  final double? priorityScore;
  final int? priorityRank;

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
      nearestEvacuationName: json['nearest_evacuation_name']?.toString(),
      nearestEvacuationLat: _doubleFrom(json['nearest_evacuation_lat']),
      nearestEvacuationLng: _doubleFrom(json['nearest_evacuation_lng']),
      nearestEvacuationDistanceKm: _doubleFrom(json['nearest_evacuation_distance_km']),
      assignedTeamId: json['assigned_team_id']?.toString(),
      assignedTeamName: json['assigned_team_name']?.toString(),
      assignedAt: DateTime.tryParse(json['assigned_at']?.toString() ?? ''),
      riskLevel: json['risk_level']?.toString(),
      priorityScore: _doubleFrom(json['priority_score']),
      priorityRank: int.tryParse(json['priority_rank']?.toString() ?? ''),
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
