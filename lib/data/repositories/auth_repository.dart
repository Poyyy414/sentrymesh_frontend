import '../../core/network/network_exceptions.dart';
import '../../core/services/storage_service.dart';
import '../models/user_model.dart';
import '../sources/remote/auth_api.dart';

class AuthRepository {
  const AuthRepository({
    required AuthApi remote,
    required StorageService storage,
  }) : _remote = remote,
       _storage = storage;

  final AuthApi _remote;
  final StorageService _storage;

  static final Map<String, _MockAuthAccount> _accounts = {
    'user123@gmail.com': const _MockAuthAccount(
      id: 'mock-user-001',
      firstName: 'Sentry',
      lastName: 'User',
      email: 'user123@gmail.com',
      address: 'Naga City, Camarines Sur',
      password: '12345678',
      role: 'user',
    ),
    'responder123@gmail.com': const _MockAuthAccount(
      id: 'mock-responder-001',
      firstName: 'Sentry',
      lastName: 'Responder',
      email: 'responder123@gmail.com',
      address: 'Naga City Command Center',
      password: '12345678',
      role: 'responder',
    ),
  };

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final account = _accounts[normalizedEmail];

    if (account == null || account.password != password) {
      throw const AuthException('Invalid email or password.');
    }

    await _storage.saveAuthToken('mock-${account.role}-${account.email}');
    return account.toUserModel();
  }

  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String address,
    required String password,
  }) async {
    try {
      final payload = await _remote.register(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().toLowerCase(),
        address: address.trim(),
        password: password,
      );

      final token = _tokenFromPayload(payload) ?? 'api-user-${email.trim()}';
      final user = _userFromPayload(
        payload,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );

      await _storage.saveAuthToken(token);
      return user;
    } on NetworkException catch (error) {
      throw AuthException(error.message);
    }
  }

  String? _tokenFromPayload(Map<String, Object?> payload) {
    return (payload['access_token'] ?? payload['token'])?.toString();
  }

  UserModel _userFromPayload(
    Map<String, Object?> payload, {
    required String firstName,
    required String lastName,
    required String email,
  }) {
    final nestedUser = payload['user'];
    if (nestedUser is Map) {
      return _userModelFromJson(
        nestedUser.map((key, value) => MapEntry(key.toString(), value)),
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
    }

    return _userModelFromJson(
      payload,
      firstName: firstName,
      lastName: lastName,
      email: email,
    );
  }

  UserModel _userModelFromJson(
    Map<String, Object?> json, {
    required String firstName,
    required String lastName,
    required String email,
  }) {
    final fallbackName = '${firstName.trim()} ${lastName.trim()}'.trim();
    final apiFirstName = json['first_name']?.toString() ?? '';
    final apiLastName = json['last_name']?.toString() ?? '';
    final apiName = json['name']?.toString();
    final fullName = apiName?.isNotEmpty == true
        ? apiName!
        : '$apiFirstName $apiLastName'.trim();

    return UserModel(
      id: json['id']?.toString() ?? 'api-user-${email.trim()}',
      name: fullName.isEmpty ? fallbackName : fullName,
      email: json['email']?.toString() ?? email.trim().toLowerCase(),
      phoneNumber: json['phone_number']?.toString(),
      role: json['role']?.toString() ?? 'user',
    );
  }

  Future<void> logout() {
    return _storage.clearAuthToken();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

class _MockAuthAccount {
  const _MockAuthAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.password,
    required this.role,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
  final String password;
  final String role;

  UserModel toUserModel() {
    return UserModel(
      id: id,
      name: '$firstName $lastName',
      email: email,
      role: role,
    );
  }
}
