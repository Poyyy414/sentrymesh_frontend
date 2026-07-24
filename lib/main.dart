import 'package:flutter/widgets.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/app.dart';
import 'core/config/map_tile_config.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapTiles').manage.create();
  // Cheap/global — harmless for residents, who never construct a MapWidget
  // (the 3D view is responder-only).
  MapboxOptions.setAccessToken(MapTileConfig.mapboxAccessToken);
  // Don't await — check connectivity in background so app starts fast
  MapTileConfig.checkConnectivity();
  final dependencies = await configureDependencies();

  runApp(SentryMeshApp(dependencies: dependencies));
}
