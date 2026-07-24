import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/sources/local/local_storage.dart';
import '../../config/map_tile_config.dart';
import '../location_service.dart';

const _kDownloadedRegionsKey = 'downloaded_map_regions';

class OfflineMapCache {
  const OfflineMapCache({required this.storage});

  final LocalStorage storage;

  /// Whether [location] falls inside a region that was previously
  /// downloaded via [downloadRegion] — real coverage, not a global flag.
  Future<bool> hasCoverageFor(GeoPoint location) async {
    final point = LatLng(location.latitude, location.longitude);
    final regions = await _readRegions();
    return regions.any((bounds) => bounds.contains(point));
  }

  /// Estimate how many tiles a bulk download of [bounds] would fetch, so the
  /// caller can show the user a size/count before committing to a download.
  Future<int> estimateTileCount(
    LatLngBounds bounds, {
    int minZoom = 10,
    int maxZoom = 16,
  }) {
    final region = RectangleRegion(bounds).toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(urlTemplate: MapTileConfig.mapboxStreetsUrl),
    );
    return const FMTCStore('mapTiles').download.countTiles(region);
  }

  /// Start a foreground bulk download of [bounds] into the shared FMTC
  /// store. Returns the same progress streams FMTC exposes — the caller
  /// drives its own progress UI from `downloadProgress`.
  ({
    Stream<TileEvent> tileEvents,
    Stream<DownloadProgress> downloadProgress,
  })
  downloadRegion(LatLngBounds bounds, {int minZoom = 10, int maxZoom = 16}) {
    final region = RectangleRegion(bounds).toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(
        urlTemplate: MapTileConfig.mapboxStreetsUrl,
        tileProvider: MapTileConfig.cachedTileProvider,
      ),
    );
    return const FMTCStore('mapTiles').download.startForeground(
      region: region,
    );
  }

  /// Record [bounds] as downloaded once a [downloadRegion] call completes,
  /// so future [hasCoverageFor] checks reflect it.
  Future<void> recordDownloadedRegion(LatLngBounds bounds) async {
    final regions = await _readRegions();
    regions.add(bounds);
    await _writeRegions(regions);
  }

  Future<List<LatLngBounds>> _readRegions() async {
    final raw = storage.read<String>(_kDownloadedRegionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, Object?>>()
          .map(
            (json) => LatLngBounds.unsafe(
              north: (json['north'] as num).toDouble(),
              south: (json['south'] as num).toDouble(),
              east: (json['east'] as num).toDouble(),
              west: (json['west'] as num).toDouble(),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeRegions(List<LatLngBounds> regions) async {
    await storage.write(
      _kDownloadedRegionsKey,
      jsonEncode(
        regions
            .map(
              (b) => {
                'north': b.north,
                'south': b.south,
                'east': b.east,
                'west': b.west,
              },
            )
            .toList(),
      ),
    );
  }
}
