import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import '../../app/theme.dart';
import '../di/injection.dart';
import '../services/geo_bounds.dart';
import '../services/location_service.dart';

/// A small floating action button that bulk-downloads map tiles around
/// [center] for offline use, so a resident or responder can pre-cache the
/// area they're operating in before losing signal instead of relying on
/// tiles happening to already be cached from prior browsing.
class OfflineMapDownloadButton extends StatelessWidget {
  const OfflineMapDownloadButton({
    required this.center,
    this.radiusKm = 15,
    this.heroTag = 'offline_map_download_fab',
    super.key,
  });

  final GeoPoint center;
  final double radiusKm;
  final String heroTag;

  Future<void> _startDownload(BuildContext context) async {
    final deps = AppDependenciesScope.of(context);
    final bounds = boundsAroundCenter(center, radiusKm);

    final estimate = await deps.offlineMapCache.estimateTileCount(bounds);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download offline maps?'),
        content: Text(
          'This downloads roughly $estimate map tiles covering '
          '${radiusKm.toStringAsFixed(0)} km around your current location, '
          'so the map keeps working here without a connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final (:tileEvents, :downloadProgress) = deps.offlineMapCache
        .downloadRegion(bounds);
    unawaited(tileEvents.drain());

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StreamBuilder<DownloadProgress>(
        stream: downloadProgress,
        builder: (ctx, snapshot) {
          final progress = snapshot.data;
          final percent = progress?.percentageProgress ?? 0;
          final done = snapshot.connectionState == ConnectionState.done;
          if (done && ctx.mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) Navigator.of(ctx).pop();
            });
          }
          return AlertDialog(
            title: const Text('Downloading offline maps'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: percent / 100),
                const SizedBox(height: 12),
                Text('${percent.toStringAsFixed(0)}% complete'),
              ],
            ),
          );
        },
      ),
    );

    await deps.offlineMapCache.recordDownloadedRegion(bounds);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offline maps ready for this area')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      backgroundColor: Colors.white,
      elevation: 3,
      tooltip: 'Download offline maps for this area',
      onPressed: () => _startDownload(context),
      child: const Icon(
        Icons.download_for_offline_rounded,
        size: 20,
        color: AppTheme.signalBlue,
      ),
    );
  }
}
