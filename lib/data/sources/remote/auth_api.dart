import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  void setAuthToken(String? token) {
    _client.setAuthToken(token);
  }

  Future<Map<String, Object?>> currentUser() {
    return _client.get(ApiEndpoints.authMe);
  }

  Future<Map<String, Object?>> login({
    required String email,
    required String password,
  }) {
    return _client.post(
      ApiEndpoints.authLogin,
      body: {'email': email, 'password': password},
    );
  }

  Future<Map<String, Object?>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String address,
    required String password,
    String? phoneNumber,
    String? responderCode,
  }) {
    return _client.post(
      ApiEndpoints.authRegister,
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'address': address,
        'password': password,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone_number': phoneNumber.trim(),
        if (responderCode != null && responderCode.trim().isNotEmpty)
          'responder_code': responderCode.trim(),
      },
    );
  }
}
