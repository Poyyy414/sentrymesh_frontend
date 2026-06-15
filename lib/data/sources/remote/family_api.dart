import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class FamilyApi {
  const FamilyApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> fetchMembers() async {
    return _client.get(ApiEndpoints.familyMembers);
  }

  Future<Map<String, Object?>> addMember(Map<String, Object?> data) async {
    return _client.post(ApiEndpoints.familyMembers, body: data);
  }

  Future<Map<String, Object?>> updateMyStatus({
    required String name,
    required String status,
  }) async {
    return _client.patch(ApiEndpoints.familyMyStatus, body: {
      'name': name,
      'status': status,
    });
  }
}

