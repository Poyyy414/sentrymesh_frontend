class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    required this.status,
    required this.memberCount,
    required this.members,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String status;
  final int memberCount;
  final List<TeamMemberModel> members;
  final DateTime createdAt;

  factory TeamModel.fromJson(Map<String, Object?> json) {
    final rawMembers = json['members'];
    final members = rawMembers is List
        ? rawMembers
              .whereType<Map<String, Object?>>()
              .map(TeamMemberModel.fromJson)
              .toList()
        : const <TeamMemberModel>[];

    return TeamModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'standby',
      memberCount:
          int.tryParse(json['member_count']?.toString() ?? '') ??
          members.length,
      members: members,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'member_count': memberCount,
      'members': members.map((m) => m.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class TeamMemberModel {
  const TeamMemberModel({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String role;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;

  String get fullName => '$firstName $lastName'.trim();

  bool get hasLocation => latitude != null && longitude != null;

  factory TeamMemberModel.fromJson(Map<String, Object?> json) {
    return TeamMemberModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      latitude: _doubleFrom(json['latitude'] ?? json['lat']),
      longitude: _doubleFrom(json['longitude'] ?? json['lng'] ?? json['lon']),
      locationUpdatedAt: DateTime.tryParse(
        json['location_updated_at']?.toString() ?? '',
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationUpdatedAt != null)
        'location_updated_at': locationUpdatedAt!.toIso8601String(),
    };
  }

  TeamMemberModel copyWith({
    double? latitude,
    double? longitude,
    DateTime? locationUpdatedAt,
  }) {
    return TeamMemberModel(
      id: id,
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      role: role,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
    );
  }

  static double? _doubleFrom(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
