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

  // Explicit --dart-define overrides always win, for setups where the
  // tower isn't reachable at its usual hotspot gateway address (e.g.
  // routed networks). Otherwise the host is discovered at runtime — see
  // [setDiscoveredTowerHost] — since a single hardcoded IP only matches
  // one specific hotspot configuration (NetworkManager's default).
  static const _towerApiUrlOverride = String.fromEnvironment(
    'SENTRYMESH_TOWER_API_URL',
  );
  static const _towerAiUrlOverride = String.fromEnvironment(
    'SENTRYMESH_TOWER_AI_URL',
  );
  static const _towerTileUrlOverride = String.fromEnvironment(
    'SENTRYMESH_TOWER_TILE_URL',
  );

  static const _defaultTowerHost = '10.42.0.1';
  static String _discoveredTowerHost = _defaultTowerHost;

  static String get towerApiUrl => _towerApiUrlOverride.isNotEmpty
      ? _towerApiUrlOverride
      : 'http://$_discoveredTowerHost:3000';

  static String get towerAiUrl => _towerAiUrlOverride.isNotEmpty
      ? _towerAiUrlOverride
      : 'http://$_discoveredTowerHost:8000';

  static String get towerTileUrl => _towerTileUrlOverride.isNotEmpty
      ? _towerTileUrlOverride
      : 'http://$_discoveredTowerHost:8085';

  /// Called once [TowerDiscovery] confirms a live tower host on the local
  /// network, so subsequent reads of [towerApiUrl]/[towerAiUrl]/
  /// [towerTileUrl] point at the address that's actually reachable.
  static void setDiscoveredTowerHost(String host) {
    _discoveredTowerHost = host;
  }

  static const cloudApiUrl = apiBaseUrl;
  static const cloudAiUrl = aiBaseUrl;

  static const apiConfig = ApiConfig(baseUrl: apiBaseUrl);
  static const aiConfig = ApiConfig(baseUrl: aiBaseUrl);
}
