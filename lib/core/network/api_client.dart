import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_config.dart';
import 'network_exceptions.dart';

class ApiClient {
  const ApiClient({required this.config});

  final ApiConfig config;

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    return _send('GET', path, queryParameters: queryParameters);
  }

  Future<Map<String, Object?>> post(String path, {Object? body}) async {
    return _send('POST', path, body: body);
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    final uri = config.resolve(path, queryParameters: queryParameters);
    final client = HttpClient()..connectionTimeout = config.timeout;

    try {
      final request = await client.openUrl(method, uri).timeout(config.timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(config.timeout);
      final responseText = await utf8.decoder
          .bind(response)
          .join()
          .timeout(config.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NetworkException(
          _errorMessage(responseText, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      if (responseText.trim().isEmpty) {
        return const {};
      }

      return _jsonToMap(jsonDecode(responseText));
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      throw NetworkException('Request timed out: $uri');
    } on SocketException catch (error) {
      throw NetworkException(
        'Could not connect to FastAPI at $uri. ${error.message}',
      );
    } on FormatException {
      throw NetworkException('FastAPI returned invalid JSON: $uri');
    } finally {
      client.close(force: true);
    }
  }

  Map<String, Object?> _jsonToMap(Object? decoded) {
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    if (decoded is List) {
      return {'items': decoded};
    }

    return {'value': decoded};
  }

  String _errorMessage(String body, int statusCode) {
    if (body.trim().isEmpty) {
      return 'FastAPI request failed with status $statusCode.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail =
            decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (detail != null) {
          return detail.toString();
        }
      }
    } catch (_) {
      // Keep the raw response below.
    }

    return body;
  }
}
