import 'dart:convert';
import 'dart:io';

/// Confirms a host is actually running the SentryMesh backend, not just
/// something answering on the same port. A bare TCP connect check used to
/// be treated as "reachable", which is a real false-positive risk for the
/// tower specifically: its candidate address is a network's ".1" gateway,
/// and on plenty of WiFi networks that's a router that happens to answer
/// on the same port for something unrelated (an admin UI, another dev
/// server, etc).
Future<bool> isSentryMeshBackend(
  String baseUrl, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client
        .getUrl(Uri.parse('$baseUrl/health'))
        .timeout(timeout);
    final response = await request.close().timeout(timeout);
    if (response.statusCode != 200) {
      return false;
    }
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(timeout);
    final decoded = jsonDecode(body);
    return decoded is Map && decoded['service'] == 'sentrymesh-backend';
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
