import '../../core/services/connectivity_service.dart';
import '../../core/services/offline/offline_data_cache.dart';
import '../models/team_model.dart';
import '../sources/remote/teams_api.dart';

class TeamRepository {
  const TeamRepository({
    required TeamsApi remote,
    required ConnectivityService connectivityService,
    required OfflineDataCache offlineDataCache,
  }) : _remote = remote,
       _connectivityService = connectivityService,
       _offlineDataCache = offlineDataCache;

  final TeamsApi _remote;
  final ConnectivityService _connectivityService;
  final OfflineDataCache _offlineDataCache;

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

  Future<TeamModel> createTeam(String name, String userId) async {
    final payload = await _remote.createTeam(name, userId);
    return TeamModel.fromJson(payload);
  }

  Future<void> joinTeam(String teamId, String userId) async {
    await _remote.joinTeam(teamId, userId);
  }

  Future<void> leaveTeam(String teamId, String userId) async {
    await _remote.leaveTeam(teamId, userId);
  }

  Future<void> updateLocation(
    String teamId,
    String userId,
    double lat,
    double lng,
  ) async {
    await _remote.updateLocation(teamId, userId, lat, lng);
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
}
