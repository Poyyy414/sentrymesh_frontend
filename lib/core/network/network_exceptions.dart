class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get hasServerResponse => statusCode != null;

  @override
  String toString() => 'NetworkException: $message';
}
