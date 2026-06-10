import 'api_config.dart';

class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_API_BASE_URL',
    defaultValue: 'https://centrimeshx.onrender.com',
  );

  static const apiConfig = ApiConfig(baseUrl: apiBaseUrl);
}
