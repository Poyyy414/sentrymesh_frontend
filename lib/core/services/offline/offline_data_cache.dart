import 'dart:convert';

import '../../../data/models/alert_model.dart';
import '../../../data/models/evacuation_center_model.dart';
import '../../../data/models/team_model.dart';
import '../../../data/sources/local/local_storage.dart';

class OfflineDataCache {
  OfflineDataCache({required LocalStorage storage}) : _storage = storage;

  final LocalStorage _storage;

  // --- Evacuation Centers ---

  Future<void> cacheEvacuationCenters(
    List<EvacuationCenterModel> centers,
  ) async {
    await _storage.write(
      'cached_evacuation_centers',
      jsonEncode(centers.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<EvacuationCenterModel>> getCachedEvacuationCenters() async {
    return _readList(
      'cached_evacuation_centers',
      EvacuationCenterModel.fromJson,
    );
  }

  // --- Teams ---

  Future<void> cacheTeams(List<TeamModel> teams) async {
    await _storage.write(
      'cached_teams',
      jsonEncode(teams.map((t) => t.toJson()).toList()),
    );
  }

  Future<List<TeamModel>> getCachedTeams() async {
    return _readList('cached_teams', TeamModel.fromJson);
  }

  // --- Alerts ---

  Future<void> cacheAlerts(List<AlertModel> alerts) async {
    await _storage.write(
      'cached_alerts',
      jsonEncode(alerts.map((a) => a.toJson()).toList()),
    );
  }

  Future<List<AlertModel>> getCachedAlerts() async {
    return _readList('cached_alerts', AlertModel.fromJson);
  }

  // --- Helpers ---

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, Object?>) fromJson,
  ) async {
    final raw = _storage.read<String>(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => fromJson(Map<String, Object?>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
