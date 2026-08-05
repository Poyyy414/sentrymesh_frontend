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

  Future<Map<String, Object?>> updateMyStatus({required String status}) async {
    return _client.patch(ApiEndpoints.familyMyStatus, body: {
      'status': status,
    });
  }

  Future<Map<String, Object?>> updateMemberStatus({
    required String id,
    required String status,
  }) async {
    return _client.patch(
      ApiEndpoints.familyMemberStatus(id),
      body: {'status': status},
    );
  }

  Future<void> removeMember(String id) async {
    await _client.delete(ApiEndpoints.familyMemberById(id));
  }

  Future<Map<String, Object?>> sendMessage(Map<String, Object?> data) async {
    return _client.post(ApiEndpoints.familyMessages, body: data);
  }

  Future<Map<String, Object?>> fetchInvites() async {
    return _client.get(ApiEndpoints.familyInvites);
  }

  Future<Map<String, Object?>> acceptInvite(String id) async {
    return _client.patch(ApiEndpoints.familyInviteAccept(id));
  }

  Future<Map<String, Object?>> declineInvite(String id) async {
    return _client.patch(ApiEndpoints.familyInviteDecline(id));
  }
}

