import 'api_config.dart';

class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_API_BASE_URL',
    defaultValue: 'https://backend-mesh-iz8d.onrender.com',
  );

  static const aiBaseUrl = String.fromEnvironment(
    'SENTRYMESH_AI_BASE_URL',
    defaultValue: 'https://sentrymesh-vigilantpath-api.onrender.com',
  );

  static const towerApiUrl = String.fromEnvironment(
    'SENTRYMESH_TOWER_API_URL',
    defaultValue: 'http://10.42.0.1:3000',
  );

  static const towerAiUrl = String.fromEnvironment(
    'SENTRYMESH_TOWER_AI_URL',
    defaultValue: 'http://10.42.0.1:8000',
  );

  static const towerTileUrl = String.fromEnvironment(
    'SENTRYMESH_TOWER_TILE_URL',
    defaultValue: 'http://10.42.0.1:8085',
  );

  static const cloudApiUrl = apiBaseUrl;
  static const cloudAiUrl = aiBaseUrl;

  static const apiConfig = ApiConfig(baseUrl: apiBaseUrl);
  static const aiConfig = ApiConfig(baseUrl: aiBaseUrl);
}
