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
  }) async {
    final payload = await _remote.addMember({
      'name': name,
      'relationship': relationship,
      'status': status,
    });

    return FamilyMemberModel.fromJson(payload);
  }
}
