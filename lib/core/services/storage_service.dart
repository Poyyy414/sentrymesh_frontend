import '../../data/sources/local/local_storage.dart';

class StorageService {
  const StorageService({required this.localStorage});

  final LocalStorage localStorage;

  Future<void> saveAuthToken(String token) {
    return localStorage.write('auth_token', token);
  }

  Future<void> saveAuthUser(Map<String, Object?> user) {
    return localStorage.write('auth_user', user);
  }

  String? readAuthToken() {
    return localStorage.read<String>('auth_token');
  }

  Map<String, Object?>? readAuthUser() {
    return localStorage.read<Map<String, Object?>>('auth_user');
  }

  Future<void> clearAuthSession() async {
    await localStorage.remove('auth_token');
    await localStorage.remove('auth_user');
  }
}
