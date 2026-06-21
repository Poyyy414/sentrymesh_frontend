class FamilyMemberModel {
  const FamilyMemberModel({
    required this.id,
    required this.name,
    required this.relationship,
    required this.status,
    required this.updatedAt,
    this.phoneNumber,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String relationship;
  final String status;
  final DateTime updatedAt;
  final String? phoneNumber;
  final String? avatarUrl;

  factory FamilyMemberModel.fromJson(Map<String, Object?> json) {
    return FamilyMemberModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      phoneNumber: json['phone_number']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'status': status,
      'updated_at': updatedAt.toIso8601String(),
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
    };
  }
}
