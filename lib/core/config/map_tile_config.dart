import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/http.dart' as http;

import 'env.dart';

class MapTileConfig {
  const MapTileConfig._();

  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue:
        'pk.eyJ1IjoiYW1wb3kiLCJhIjoiY21weTJqNGIwMDFyeTJycXl4bjVsMDVpaSJ9.EP-crdJD41BmjI5uhdamJw',
  );

  static const _osmStreetsUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const _mapboxStreets =
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  static const _mapboxSatelliteStreets =
      'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  static String get _towerStreetsUrl =>
      '${Env.towerTileUrl}/streets/{z}/{x}/{y}.png';

  static String get _towerSatelliteUrl =>
      '${Env.towerTileUrl}/satellite/{z}/{x}/{y}.png';

  static bool _hasInternet = true;
  static bool _hasTower = false;
  static bool _checked = false;

  static bool get isOnline => _hasInternet;
  static bool get isUsingTower => _checked && _hasTower;

  static Future<void> checkConnectivity() async {
    _hasTower = await _canReachTower();

    try {
      final response = await http
          .head(Uri.parse('https://api.mapbox.com'))
          .timeout(const Duration(seconds: 4));
      _hasInternet = response.statusCode < 500;
    } catch (_) {
      _hasInternet = false;
    }
    _checked = true;
  }

  static Future<bool> _canReachTower() async {
    try {
      final uri = Uri.parse(Env.towerTileUrl);
      final socket = await Socket.connect(
        uri.host,
        uri.hasPort ? uri.port : 80,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String get mapboxStreetsUrl {
    if (!_checked) return _mapboxStreets;
    if (_hasTower) return _towerStreetsUrl;
    if (!_hasInternet) return _osmStreetsUrl;
    return _mapboxStreets;
  }

  static String get mapboxSatelliteStreetsUrl {
    if (!_checked) return _mapboxSatelliteStreets;
    if (_hasTower) return _towerSatelliteUrl;
    if (!_hasInternet) return _osmStreetsUrl;
    return _mapboxSatelliteStreets;
  }

  static TileProvider get cachedTileProvider {
    return FMTCTileProvider(
      stores: const {'mapTiles': BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: BrowseLoadingStrategy.cacheFirst,
      cachedValidDuration: const Duration(days: 30),
    );
  }
}
