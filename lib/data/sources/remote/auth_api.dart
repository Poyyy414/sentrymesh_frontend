import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> login({
    required String email,
    required String password,
  }) {
    return _client.post(
      ApiEndpoints.authLogin,
      body: {
        'email': email,
        'password': password,
      },
    );
  }
}
