import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client buildTestHttpClient() => MockClient(_handler);

Future<http.Response> _handler(http.Request request) async {
  final path = request.url.path;
  final method = request.method;

  if (method == 'GET' && path == '/auth/me') {
    return http.Response('', 401);
  }

  if (method == 'POST' && path == '/auth/login') {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final email = body['email']?.toString() ?? '';
    if (email == 'user@test.com') {
      return _json(200, {
        'access_token': 'test-user-token',
        'user': {
          'id': 'user-1',
          'name': 'Test User',
          'email': email,
          'role': 'user',
        },
      });
    }
    if (email == 'responder@test.com') {
      return _json(200, {
        'access_token': 'test-responder-token',
        'user': {
          'id': 'resp-1',
          'name': 'Test Responder',
          'email': email,
          'role': 'responder',
        },
      });
    }
    return http.Response('', 401);
  }

  if (method == 'POST' && path == '/auth/register') {
    return http.Response('', 500);
  }

  if (method == 'GET' && path == '/alerts') {
    final now = DateTime.now();
    return _json(200, {
      'items': [
        {
          'id': 'alert-flood-1',
          'title': 'Flood Warning',
          'location': 'San Felipe, Naga City',
          'severity': 'high',
          'hazard_type': 'flood',
          'issued_at': DateTime(now.year, now.month, now.day, 6, 30).toIso8601String(),
        },
        {
          'id': 'alert-landslide-1',
          'title': 'Landslide Alert',
          'location': 'Cararayan, Naga City',
          'severity': 'high',
          'hazard_type': 'landslide',
          'issued_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          'id': 'alert-typhoon-1',
          'title': 'Typhoon Alert',
          'location': 'Naga City',
          'severity': 'high',
          'hazard_type': 'typhoon',
          'issued_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        },
      ],
    });
  }

  if (method == 'GET' && path == '/family/members') {
    final now = DateTime.now().toIso8601String();
    return _json(200, {
      'items': [
        {
          'id': 'maria',
          'name': 'Maria Santos',
          'relationship': 'Mother',
          'status': 'safe',
          'updated_at': now,
        },
        {
          'id': 'antonio',
          'name': 'Antonio Santos',
          'relationship': 'Father',
          'status': 'safe',
          'updated_at': now,
        },
        {
          'id': 'carmen',
          'name': 'Carmen Santos',
          'relationship': 'Sister',
          'status': 'safe',
          'updated_at': now,
        },
        {
          'id': 'bea',
          'name': 'Bea Santos',
          'relationship': 'Sister',
          'status': 'safe',
          'updated_at': now,
        },
      ],
    });
  }

  if (method == 'GET' && path == '/rescue-requests') {
    return http.Response('', 500);
  }

  if (method == 'POST' && path == '/rescue-requests') {
    return _json(200, {'id': 'sos-1'});
  }

  return _json(200, <String, Object?>{});
}

http.Response _json(int status, Object data) {
  return http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );
}
