import '../../core/network/network_exceptions.dart';
import '../../core/services/storage_service.dart';
import '../models/user_model.dart';
import '../sources/remote/auth_api.dart';

class AuthRepository {
  AuthRepository({required AuthApi remote, required StorageService storage})
    : _remote = remote,
      _storage = storage;

  final AuthApi _remote;
  final StorageService _storage;
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final payload = await _remote.login(
        email: normalizedEmail,
        password: password,
      );

      final token = _requiredToken(payload);
      final user = _userFromPayload(
        payload,
        firstName: '',
        lastName: '',
        email: normalizedEmail,
      );

      await _saveSession(token, user);
      return user;
    } on NetworkException catch (error) {
      throw AuthException(error.message);
    }
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

      final token = _requiredToken(payload);
      final user = _userFromPayload(
        payload,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );

      await _saveSession(token, user);
      return user;
    } on NetworkException catch (error) {
      throw AuthException(error.message);
    }
  }

  Future<UserModel?> restoreSession() async {
    final token = _storage.readAuthToken();
    if (token == null || token.isEmpty) return null;

    _remote.setAuthToken(token);
    try {
      final payload = await _remote.currentUser();
      final savedUser = _storage.readAuthUser();
      final user = _userFromPayload(
        payload,
        firstName: '',
        lastName: '',
        email: savedUser?['email']?.toString() ?? '',
      );
      _currentUser = user;
      await _storage.saveAuthUser(user.toJson());
      return user;
    } on NetworkException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await logout();
        return null;
      }

      final savedUser = _storage.readAuthUser();
      if (savedUser != null) {
        _currentUser = UserModel.fromJson(savedUser);
      }
      return _currentUser;
    }
  }

  String _requiredToken(Map<String, Object?> payload) {
    final token = (payload['access_token'] ?? payload['token'])?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException('Backend returned an invalid login response.');
    }
    return token;
  }

  Future<void> _saveSession(String token, UserModel user) async {
    _remote.setAuthToken(token);
    _currentUser = user;
    await _storage.saveAuthToken(token);
    await _storage.saveAuthUser(user.toJson());
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

  Future<void> logout() async {
    _remote.setAuthToken(null);
    _currentUser = null;
    await _storage.clearAuthSession();
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
