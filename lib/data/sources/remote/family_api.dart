import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class FamilyApi {
  const FamilyApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> fetchMembers() {
    return _client.get(ApiEndpoints.familyMembers);
  }
}
