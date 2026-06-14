import 'api_config.dart';

class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_API_BASE_URL',
    defaultValue: 'https://backend-mesh-t9rc.onrender.com',
  );

  static const aiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_AI_BASE_URL',
    defaultValue: 'https://apexnode-ai.onrender.com',
  );

  static const apiConfig = ApiConfig(baseUrl: apiBaseUrl);
  static const aiConfig = ApiConfig(baseUrl: aiBaseUrl);
}
