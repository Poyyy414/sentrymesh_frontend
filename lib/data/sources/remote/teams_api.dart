import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class TeamsApi {
  const TeamsApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> fetchTeams() {
    return _client.get(ApiEndpoints.teams);
  }

  Future<Map<String, Object?>> fetchAllTeamLocations() {
    return _client.get(ApiEndpoints.teamAllLocations);
  }

  Future<Map<String, Object?>> fetchTeam(String id) {
    return _client.get(ApiEndpoints.teamById(id));
  }

  Future<Map<String, Object?>> createTeam(String name, String userId) {
    return _client.post(
      ApiEndpoints.teams,
      body: {'name': name, 'user_id': userId},
    );
  }

  Future<Map<String, Object?>> joinTeam(String teamId, String userId) {
    return _client.post(
      ApiEndpoints.teamJoin(teamId),
      body: {'user_id': userId},
    );
  }

  Future<Map<String, Object?>> leaveTeam(String teamId, String userId) {
    return _client.post(
      ApiEndpoints.teamLeave(teamId),
      body: {'user_id': userId},
    );
  }

  Future<Map<String, Object?>> updateLocation(
    String teamId,
    String userId,
    double lat,
    double lng,
  ) {
    return _client.patch(
      ApiEndpoints.teamLocation(teamId),
      body: {'user_id': userId, 'latitude': lat, 'longitude': lng},
    );
  }

  Future<Map<String, Object?>> fetchLocations(String teamId) {
    return _client.get(ApiEndpoints.teamLocations(teamId));
  }
}
