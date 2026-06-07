import '../../core/services/storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  const AuthRepository({
    required StorageService storage,
  }) : _storage = storage;

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
    final normalizedEmail = email.trim().toLowerCase();

    if (_accounts.containsKey(normalizedEmail)) {
      throw const AuthException('An account already exists for this email.');
    }

    final account = _MockAuthAccount(
      id: 'mock-user-${_accounts.length + 1}',
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: normalizedEmail,
      address: address.trim(),
      password: password,
      role: 'user',
    );

    _accounts[normalizedEmail] = account;
    await _storage.saveAuthToken('mock-${account.role}-${account.email}');

    return account.toUserModel();
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
