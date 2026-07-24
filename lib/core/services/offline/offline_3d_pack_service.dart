import 'dart:convert';

import 'package:flutter_map/flutter_map.dart' hide Polygon;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../data/sources/local/local_storage.dart';
import '../geo_bounds.dart';
import '../location_service.dart';

const _kRegionsKey = 'offline_3d_pack_regions';
const _kNextIndexKey = 'offline_3d_pack_next_index';

/// Downloads the real Mapbox 3D map (style + vector tiles) for an area
/// while online, so the responder 3D view keeps working once the device is
/// tower-only with no real internet. Mapbox's SDK automatically prefers
/// this local cache over the network once it exists — no offline-mode flag
/// needs to be set on the map widget itself.
///
/// Tracks multiple downloaded regions (mirroring [OfflineMapCache]'s
/// pattern) rather than one fixed area, since [ensureCoverage] is meant to
/// silently extend coverage to wherever the responder actually ends up,
/// not just one manually-chosen spot.
class Offline3DPackService {
  Offline3DPackService({required this.storage});

  final LocalStorage storage;

  static const _styleUri = MapboxStyles.STANDARD;
  static const _minZoom = 10;
  static const _maxZoom = 16;

  OfflineManager? _offlineManager;
  TileStore? _tileStore;

  Future<(OfflineManager, TileStore)> _ensureInitialized() async {
    final manager = _offlineManager ??= await OfflineManager.create();
    final store = _tileStore ??= await TileStore.createDefault();
    return (manager, store);
  }

  /// Whether [location] falls inside a region that was already downloaded.
  Future<bool> hasCoverageFor(GeoPoint location) async {
    final point = LatLng(location.latitude, location.longitude);
    final regions = await _readRegions();
    return regions.any((r) => r.bounds.contains(point));
  }

  /// Whether the style pack itself (shared across all regions) is ready.
  Future<bool> _hasStylePackReady() async {
    final (manager, _) = await _ensureInitialized();
    final stylePacks = await manager.allStylePacks();
    final match = stylePacks.where((p) => p.styleURI == _styleUri);
    if (match.isEmpty) return false;
    final style = match.first;
    return style.completedResourceCount >= style.requiredResourceCount;
  }

  /// Whether [location] is fully ready for offline 3D use right now: the
  /// shared style pack is complete, and a tile region covering it exists.
  Future<bool> hasPackReady(GeoPoint location) async {
    if (!await _hasStylePackReady()) return false;
    return hasCoverageFor(location);
  }

  /// If [location] isn't already covered, silently downloads a new region
  /// around it. Safe to call repeatedly — a no-op once covered.
  Future<void> ensureCoverage(GeoPoint location, {double radiusKm = 15}) async {
    if (await hasCoverageFor(location)) return;

    final bounds = boundsAroundCenter(location, radiusKm);
    final regionId = await _nextRegionId();
    await _download(regionId, bounds, onProgress: (_) {});
    await _recordRegion(regionId, bounds);
  }

  Future<void> _download(
    String regionId,
    LatLngBounds bounds, {
    required void Function(double progress) onProgress,
  }) async {
    final (manager, store) = await _ensureInitialized();

    if (!await _hasStylePackReady()) {
      await manager.loadStylePack(
        _styleUri,
        StylePackLoadOptions(acceptExpired: false),
        (progress) => onProgress(
          0.5 *
              progress.completedResourceCount /
              progress.requiredResourceCount,
        ),
      );
    } else {
      onProgress(0.5);
    }

    await store.loadTileRegion(
      regionId,
      _loadOptions(bounds),
      (progress) => onProgress(
        0.5 +
            0.5 *
                progress.completedResourceCount /
                progress.requiredResourceCount,
      ),
    );
  }

  TileRegionLoadOptions _loadOptions(LatLngBounds bounds) {
    return TileRegionLoadOptions(
      geometry: Polygon.fromPoints(
        points: [
          [
            Point(coordinates: Position(bounds.west, bounds.south)),
            Point(coordinates: Position(bounds.east, bounds.south)),
            Point(coordinates: Position(bounds.east, bounds.north)),
            Point(coordinates: Position(bounds.west, bounds.north)),
            Point(coordinates: Position(bounds.west, bounds.south)),
          ],
        ],
      ).toJson(),
      descriptorsOptions: [
        TilesetDescriptorOptions(
          styleURI: _styleUri,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
        ),
      ],
      acceptExpired: false,
      networkRestriction: NetworkRestriction.NONE,
    );
  }

  Future<String> _nextRegionId() async {
    final index = storage.read<int>(_kNextIndexKey) ?? 0;
    await storage.write(_kNextIndexKey, index + 1);
    return 'responder-3d-pack-$index';
  }

  Future<List<({String id, LatLngBounds bounds})>> _readRegions() async {
    final raw = storage.read<String>(_kRegionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, Object?>>().map((json) {
        return (
          id: json['id'] as String,
          bounds: LatLngBounds.unsafe(
            north: (json['north'] as num).toDouble(),
            south: (json['south'] as num).toDouble(),
            east: (json['east'] as num).toDouble(),
            west: (json['west'] as num).toDouble(),
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _recordRegion(String id, LatLngBounds bounds) async {
    final regions = await _readRegions();
    regions.add((id: id, bounds: bounds));
    await storage.write(
      _kRegionsKey,
      jsonEncode(
        regions
            .map(
              (r) => {
                'id': r.id,
                'north': r.bounds.north,
                'south': r.bounds.south,
                'east': r.bounds.east,
                'west': r.bounds.west,
              },
            )
            .toList(),
      ),
    );
  }
}
