class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.role = 'user',
  });

  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String role;

  factory UserModel.fromJson(Map<String, Object?> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      role: json['role']?.toString() ?? 'user',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'role': role,
    };
  }
}
