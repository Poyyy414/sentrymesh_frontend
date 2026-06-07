import '../../../data/sources/local/local_storage.dart';
import '../location_service.dart';

class OfflineMapCache {
  const OfflineMapCache({required this.storage});

  final LocalStorage storage;

  Future<bool> hasCoverageFor(GeoPoint location) async {
    return storage.read<bool>('offline_maps_enabled') ?? false;
  }

  Future<void> markCoverageAvailable() async {
    await storage.write('offline_maps_enabled', true);
  }
}
