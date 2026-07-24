import '../../core/services/connectivity_service.dart';
import '../../core/services/offline/offline_data_cache.dart';
import '../../core/services/offline/sync_queue.dart';
import '../models/family_member_model.dart';
import '../sources/remote/family_api.dart';

class FamilyRepository {
  const FamilyRepository({
    required FamilyApi remote,
    required ConnectivityService connectivityService,
    required OfflineDataCache offlineDataCache,
    required SyncQueue syncQueue,
  }) : _remote = remote,
       _connectivityService = connectivityService,
       _offlineDataCache = offlineDataCache,
       _syncQueue = syncQueue;

  final FamilyApi _remote;
  final ConnectivityService _connectivityService;
  final OfflineDataCache _offlineDataCache;
  final SyncQueue _syncQueue;

  Future<List<FamilyMemberModel>> fetchMembers() async {
    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      return _offlineDataCache.getCachedFamilyMembers();
    }

    try {
      final payload = await _remote.fetchMembers();
      final items = payload['items'];
      if (items is! List) {
        return const [];
      }

      final members = items
          .whereType<Map<String, Object?>>()
          .map(FamilyMemberModel.fromJson)
          .toList();
      await _offlineDataCache.cacheFamilyMembers(members);
      return members;
    } catch (_) {
      return _offlineDataCache.getCachedFamilyMembers();
    }
  }

  Future<FamilyMemberModel> addMember({
    required String name,
    required String relationship,
    required String status,
    String? phoneNumber,
  }) async {
    final body = {
      'name': name,
      'relationship': relationship,
      'status': status,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
    };
    final payload = await _writeOrQueue(
      type: 'family_add_member',
      endpoint: '/family/members',
      method: 'POST',
      body: body,
      send: () => _remote.addMember(body),
    );
    return FamilyMemberModel.fromJson(payload);
  }

  Future<void> removeMember(String id) async {
    await _writeOrQueue(
      type: 'family_remove_member',
      endpoint: '/family/members/$id',
      method: 'DELETE',
      body: const {},
      send: () async {
        await _remote.removeMember(id);
        return const {};
      },
    );
  }

  Future<void> sendMessage({
    required String toNumber,
    required String body,
    String? toName,
    String? fromName,
  }) async {
    final payload = {
      'to_number': toNumber,
      'body': body,
      'to_name': ?toName,
      'from_name': ?fromName,
    };
    await _writeOrQueue(
      type: 'family_message',
      endpoint: '/family/messages',
      method: 'POST',
      body: payload,
      send: () => _remote.sendMessage(payload),
    );
  }

  Future<void> updateMyStatus({required String status}) async {
    await _writeOrQueue(
      type: 'family_my_status',
      endpoint: '/family/my-status',
      method: 'PATCH',
      body: {'status': status},
      send: () => _remote.updateMyStatus(status: status),
    );
  }

  Future<void> updateMemberStatus({
    required String id,
    required String status,
  }) async {
    await _writeOrQueue(
      type: 'family_member_status',
      endpoint: '/family/members/$id/status',
      method: 'PATCH',
      body: {'status': status},
      send: () => _remote.updateMemberStatus(id: id, status: status),
    );
  }

  /// Shared write path for every family mutation: send immediately while
  /// online, or queue it for later delivery (offline, or the live call
  /// failed) and signal that via [QueuedForSyncException] rather than
  /// pretending the write succeeded — callers must not show a plain
  /// "success" message when this throws.
  Future<Map<String, Object?>> _writeOrQueue({
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
      return await send();
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
