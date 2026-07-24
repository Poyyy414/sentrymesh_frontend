import '../../core/services/connectivity_service.dart';
import '../../core/services/offline/offline_data_cache.dart';
import '../../core/services/offline/sync_queue.dart';
import '../models/team_model.dart';
import '../sources/remote/teams_api.dart';

class TeamRepository {
  const TeamRepository({
    required TeamsApi remote,
    required ConnectivityService connectivityService,
    required OfflineDataCache offlineDataCache,
    required SyncQueue syncQueue,
  }) : _remote = remote,
       _connectivityService = connectivityService,
       _offlineDataCache = offlineDataCache,
       _syncQueue = syncQueue;

  final TeamsApi _remote;
  final ConnectivityService _connectivityService;
  final OfflineDataCache _offlineDataCache;
  final SyncQueue _syncQueue;

  Future<List<TeamModel>> fetchTeams() async {
    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      return _offlineDataCache.getCachedTeams();
    }

    try {
      final payload = await _remote.fetchTeams();
      final items = payload['items'];
      if (items is! List) return const [];
      final teams = items
          .whereType<Map<String, Object?>>()
          .map(TeamModel.fromJson)
          .toList();
      await _offlineDataCache.cacheTeams(teams);
      return teams;
    } catch (_) {
      return _offlineDataCache.getCachedTeams();
    }
  }

  Future<TeamModel> fetchTeam(String id) async {
    final payload = await _remote.fetchTeam(id);
    return TeamModel.fromJson(payload);
  }

  // Creating a team needs a server-generated id — unlike joinTeam/leaveTeam/
  // updateLocation there's no client-side id to queue against and return
  // immediately, so this stays a plain call the user would retry manually.
  Future<TeamModel> createTeam(String name, String userId) async {
    final payload = await _remote.createTeam(name, userId);
    return TeamModel.fromJson(payload);
  }

  Future<void> joinTeam(String teamId, String userId) async {
    await _writeOrQueue(
      type: 'team_join',
      endpoint: '/teams/$teamId/join',
      method: 'POST',
      body: {'user_id': userId},
      send: () => _remote.joinTeam(teamId, userId),
    );
  }

  Future<void> leaveTeam(String teamId, String userId) async {
    await _writeOrQueue(
      type: 'team_leave',
      endpoint: '/teams/$teamId/leave',
      method: 'POST',
      body: {'user_id': userId},
      send: () => _remote.leaveTeam(teamId, userId),
    );
  }

  Future<void> updateLocation(
    String teamId,
    String userId,
    double lat,
    double lng,
  ) async {
    await _writeOrQueue(
      type: 'team_location',
      endpoint: '/teams/$teamId/location',
      method: 'PATCH',
      body: {'user_id': userId, 'latitude': lat, 'longitude': lng},
      send: () => _remote.updateLocation(teamId, userId, lat, lng),
    );
  }

  Future<List<TeamModel>> fetchAllTeamsWithLocations() async {
    final payload = await _remote.fetchAllTeamLocations();
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, Object?>>()
        .map(TeamModel.fromJson)
        .toList();
  }

  Future<List<TeamMemberModel>> fetchLocations(String teamId) async {
    final payload = await _remote.fetchLocations(teamId);
    final items = payload['members'] ?? payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, Object?>>()
        .map(TeamMemberModel.fromJson)
        .toList();
  }

  /// Shared write path: send immediately while online, or queue for later
  /// delivery and signal that via [QueuedForSyncException] — mirrors the
  /// same pattern already used by RescueRepository/FamilyRepository/
  /// AlertRepository, so a caller failure/offline state is never mistaken
  /// for a delivered write.
  Future<void> _writeOrQueue({
    required String type,
    required String endpoint,
    required String method,
    required Map<String, Object?> body,
    required Future<Map<String, Object?>> Function() send,
  }) async {
    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      await _enqueue(type, endpoint, method, body);
      throw const QueuedForSyncException();
    }

    try {
      await send();
    } catch (_) {
      await _enqueue(type, endpoint, method, body);
      throw const QueuedForSyncException();
    }
  }

  Future<void> _enqueue(
    String type,
    String endpoint,
    String method,
    Map<String, Object?> body,
  ) {
    return _syncQueue.enqueue(SyncOperation(
      id: '${type}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      endpoint: endpoint,
      method: method,
      body: body,
      createdAt: DateTime.now(),
    ));
  }
}
