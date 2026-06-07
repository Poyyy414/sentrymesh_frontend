import '../config/api_config.dart';
import 'network_exceptions.dart';

class ApiClient {
  const ApiClient({required this.config});

  final ApiConfig config;

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    throw NetworkException(
      'FastAPI client is not connected yet: ${config.resolve(path, queryParameters: queryParameters)}',
    );
  }

  Future<Map<String, Object?>> post(String path, {Object? body}) async {
    throw NetworkException(
      'FastAPI client is not connected yet: ${config.resolve(path)}',
    );
  }
}
