import 'api_config.dart';

class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_API_BASE_URL',
    defaultValue: 'https://sentrymesh-backend.onrender.com',
  );

  static const aiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_AI_BASE_URL',
    defaultValue: 'https://sentrymesh-vigilantpath-api.onrender.com',
  );

  static const apiConfig = ApiConfig(baseUrl: apiBaseUrl);
  static const aiConfig = ApiConfig(baseUrl: aiBaseUrl);
}
