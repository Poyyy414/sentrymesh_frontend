class FamilyInviteModel {
  const FamilyInviteModel({
    required this.id,
    required this.fromName,
    required this.createdAt,
  });

  final String id;
  final String fromName;
  final DateTime createdAt;

  factory FamilyInviteModel.fromJson(Map<String, Object?> json) {
    return FamilyInviteModel(
      id: json['id']?.toString() ?? '',
      fromName: json['from_name']?.toString() ?? 'Someone',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
