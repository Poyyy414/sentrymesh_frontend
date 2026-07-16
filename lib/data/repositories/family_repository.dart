import '../models/family_member_model.dart';
import '../sources/remote/family_api.dart';

class FamilyRepository {
  const FamilyRepository({required FamilyApi remote}) : _remote = remote;

  final FamilyApi _remote;

  Future<List<FamilyMemberModel>> fetchMembers() async {
    final payload = await _remote.fetchMembers();
    final items = payload['items'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, Object?>>()
        .map(FamilyMemberModel.fromJson)
        .toList();
  }

  Future<FamilyMemberModel> addMember({
    required String name,
    required String relationship,
    required String status,
    String? phoneNumber,
  }) async {
    final payload = await _remote.addMember({
      'name': name,
      'relationship': relationship,
      'status': status,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
    });

    return FamilyMemberModel.fromJson(payload);
  }

  Future<void> removeMember(String id) async {
    await _remote.removeMember(id);
  }

  Future<void> sendMessage({
    required String toNumber,
    required String body,
    String? toName,
    String? fromName,
  }) async {
    await _remote.sendMessage({
      'to_number': toNumber,
      'body': body,
      'to_name': ?toName,
      'from_name': ?fromName,
    });
  }

  Future<void> updateMyStatus({
    required String name,
    required String status,
  }) async {
    await _remote.updateMyStatus(name: name, status: status);
  }
}
