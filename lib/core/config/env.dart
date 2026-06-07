import 'api_config.dart';

class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const apiConfig = ApiConfig(baseUrl: apiBaseUrl);
}
