import '../../data/sources/local/local_storage.dart';

class StorageService {
  const StorageService({required this.localStorage});

  final LocalStorage localStorage;

  Future<void> saveAuthToken(String token) {
    return localStorage.write('auth_token', token);
  }

  String? readAuthToken() {
    return localStorage.read<String>('auth_token');
  }

  Future<void> clearAuthToken() {
    return localStorage.write('auth_token', '');
  }
}
