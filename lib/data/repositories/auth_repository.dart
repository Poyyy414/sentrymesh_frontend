import '../../core/network/network_exceptions.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/storage_service.dart';
import '../models/user_model.dart';
import '../sources/remote/auth_api.dart';

class AuthRepository {
  AuthRepository({
    required AuthApi remote,
    required StorageService storage,
    required ConnectivityService connectivity,
  }) : _remote = remote,
       _storage = storage,
       _connectivity = connectivity;

  final AuthApi _remote;
  final StorageService _storage;
  final ConnectivityService _connectivity;
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  // Accounts only ever exist wherever they were created — a tower has no
  // way to hand a freshly-registered or freshly-authenticated account to the
  // cloud, and a "logged out" tower-only device could never log back in.
  // So registration, login, and logout are all gated on genuine cloud
  // reachability, never just the tower.
  Future<void> _requireCloud(String action) async {
    final reachable = await _connectivity.isCloudReachable();
    if (!reachable) {
      throw AuthException(
        'Please connect to the internet to $action. This is not possible while only connected to a tower.',
      );
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    await _requireCloud('log in');
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
    String? responderCode,
  }) async {
    await _requireCloud('register');
    try {
      final payload = await _remote.register(
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().toLowerCase(),
        address: address.trim(),
        password: password,
        responderCode: responderCode,
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
        // The server itself just rejected this token, so we're necessarily
        // online right now — clear directly rather than through the public
        // logout(), which enforces its own connectivity gate for user-
        // initiated logouts and isn't needed for this forced cleanup.
        await _clearSession();
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

  Future<void> updateCurrentUserLocally(UserModel updatedUser) async {
    _currentUser = updatedUser;
    await _storage.saveAuthUser(updatedUser.toJson());
  }

  Future<void> logout() async {
    await _requireCloud('log out');
    await _clearSession();
  }

  Future<void> _clearSession() async {
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
