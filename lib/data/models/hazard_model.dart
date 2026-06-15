import '../../shared/enums/hazard_type.dart';

class HazardModel {
  const HazardModel({
    required this.id,
    required this.type,
    required this.confidence,
    required this.severityScore,
    required this.updatedAt,
    this.locationLabel,
  });

  final String id;
  final HazardType type;
  final double confidence;
  final double severityScore;
  final DateTime updatedAt;
  final String? locationLabel;

  factory HazardModel.fromJson(Map<String, Object?> json) {
    return HazardModel(
      id: json['id']?.toString() ?? '',
      type: HazardType.values.firstWhere(
        (type) => type.name == json['type']?.toString(),
        orElse: () => HazardType.distress,
      ),
      confidence: _asDouble(json['confidence']),
      severityScore: _asDouble(json['severity_score']),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      locationLabel: json['location_label']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      'confidence': confidence,
      'severity_score': severityScore,
      'updated_at': updatedAt.toIso8601String(),
      'location_label': locationLabel,
    };
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
