class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final Duration timeout;

  Uri resolve(String path, {Map<String, String>? queryParameters}) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    return base.replace(
      path: '${base.path}/$normalizedPath'.replaceAll('//', '/'),
      queryParameters: queryParameters,
    );
  }
}
