import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'network_exceptions.dart';

class ApiClient {
  ApiClient({required ApiConfig config, http.Client? client})
    : _config = config,
      _client = client ?? http.Client();

  ApiConfig _config;
  final http.Client _client;

  ApiConfig get config => _config;

  void updateBaseUrl(String newBaseUrl) {
    _config = ApiConfig(baseUrl: newBaseUrl, timeout: _config.timeout);
  }
  String? _authToken;

  void setAuthToken(String? token) {
    final normalized = token?.trim();
    _authToken = normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    return _send('GET', path, queryParameters: queryParameters);
  }

  Future<Map<String, Object?>> post(String path, {Object? body}) async {
    return _send('POST', path, body: body);
  }

  Future<Map<String, Object?>> patch(String path, {Object? body}) async {
    return _send('PATCH', path, body: body);
  }

  Future<Map<String, Object?>> delete(String path, {Object? body}) async {
    return _send('DELETE', path, body: body);
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    final uri = config.resolve(path, queryParameters: queryParameters);

    try {
      final headers = <String, String>{'accept': 'application/json'};
      if (_authToken != null) {
        headers['authorization'] = 'Bearer $_authToken';
      }

      if (body != null) {
        headers['content-type'] = 'application/json';
      }

      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body);
      final streamedResponse = await _client
          .send(request)
          .timeout(config.timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(config.timeout);
      final responseText = response.body;

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
    } on http.ClientException catch (error) {
      throw NetworkException(
        'Could not connect to API at $uri. ${error.message}',
      );
    } on FormatException {
      throw NetworkException('API returned invalid JSON: $uri');
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
      return 'API request failed with status $statusCode.';
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
