import 'local_storage.dart';

class CacheManager {
  const CacheManager({required this.storage});

  final LocalStorage storage;

  Future<void> saveJson(String key, Map<String, Object?> value) {
    return storage.write(key, value);
  }

  Map<String, Object?>? readJson(String key) {
    return storage.read<Map<String, Object?>>(key);
  }
}
