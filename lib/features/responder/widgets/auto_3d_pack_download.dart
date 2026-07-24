import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../../core/config/map_tile_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/location_service.dart';

/// Silently extends the responder 3D offline pack to cover [location],
/// restricted to Wi-Fi so it never burns a responder's mobile data without
/// them knowing. A no-op if [location] is null, there's no real internet,
/// the connection isn't Wi-Fi, or the area is already covered.
Future<void> maybeAutoDownload3DPack({
  required BuildContext context,
  required GeoPoint? location,
}) async {
  if (location == null || !MapTileConfig.isOnline) return;

  final connectivity = await Connectivity().checkConnectivity();
  if (!connectivity.contains(ConnectivityResult.wifi)) return;

  if (!context.mounted) return;
  await AppDependenciesScope.of(
    context,
  ).offline3DPackService.ensureCoverage(location);
}
