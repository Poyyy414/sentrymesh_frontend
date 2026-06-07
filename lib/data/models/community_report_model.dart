import '../../shared/enums/hazard_type.dart';

class CommunityReportModel {
  const CommunityReportModel({
    required this.id,
    required this.message,
    required this.hazardType,
    required this.confidenceScore,
    required this.submittedAt,
    this.locationLabel,
  });

  final String id;
  final String message;
  final HazardType hazardType;
  final double confidenceScore;
  final DateTime submittedAt;
  final String? locationLabel;

  factory CommunityReportModel.fromJson(Map<String, Object?> json) {
    return CommunityReportModel(
      id: json['id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      hazardType: HazardType.values.firstWhere(
        (type) => type.name == json['hazard_type']?.toString(),
        orElse: () => HazardType.distress,
      ),
      confidenceScore: _asDouble(json['confidence_score']),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? '') ?? DateTime.now(),
      locationLabel: json['location_label']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'message': message,
      'hazard_type': hazardType.name,
      'confidence_score': confidenceScore,
      'submitted_at': submittedAt.toIso8601String(),
      'location_label': locationLabel,
    };
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
