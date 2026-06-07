import '../../shared/enums/alert_severity.dart';
import '../../shared/enums/hazard_type.dart';

class AlertModel {
  const AlertModel({
    required this.id,
    required this.title,
    required this.location,
    required this.message,
    required this.severity,
    required this.hazardType,
    required this.issuedAt,
  });

  final String id;
  final String title;
  final String location;
  final String message;
  final AlertSeverity severity;
  final HazardType hazardType;
  final DateTime issuedAt;

  factory AlertModel.fromJson(Map<String, Object?> json) {
    return AlertModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      severity: _severityFromJson(json['severity']),
      hazardType: _hazardTypeFromJson(json['hazard_type']),
      issuedAt: DateTime.tryParse(json['issued_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'message': message,
      'severity': severity.name,
      'hazard_type': hazardType.name,
      'issued_at': issuedAt.toIso8601String(),
    };
  }

  static AlertSeverity _severityFromJson(Object? value) {
    return AlertSeverity.values.firstWhere(
      (severity) => severity.name == value?.toString(),
      orElse: () => AlertSeverity.low,
    );
  }

  static HazardType _hazardTypeFromJson(Object? value) {
    return HazardType.values.firstWhere(
      (type) => type.name == value?.toString(),
      orElse: () => HazardType.distress,
    );
  }
}
