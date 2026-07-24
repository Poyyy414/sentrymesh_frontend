import 'dart:convert';

import '../../../data/sources/local/local_storage.dart';
import '../../network/api_client.dart';

/// Thrown by repository writes when a change was queued locally for later
/// delivery (offline, or the live request failed) instead of actually
/// reaching the backend. Callers must catch this separately from a real
/// failure — showing a plain "success" message here would tell the user
/// something happened (a family member was alerted, a status changed) when
/// nothing has actually left the device yet.
class QueuedForSyncException implements Exception {
  const QueuedForSyncException([
    this.message = 'Saved locally — will sync once back online.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String endpoint;
  final String method;
  final Map<String, Object?> body;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'endpoint': endpoint,
    'method': method,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  factory SyncOperation.fromJson(Map<String, Object?> json) {
    return SyncOperation(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      endpoint: json['endpoint']?.toString() ?? '',
      method: json['method']?.toString() ?? 'POST',
      body: json['body'] is Map
          ? Map<String, Object?>.from(json['body'] as Map)
          : const {},
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class SyncQueue {
  SyncQueue({required LocalStorage storage}) : _storage = storage;

  final LocalStorage _storage;
  static const _key = 'sync_queue_items';

  Future<void> enqueue(SyncOperation op) async {
    final items = await pending();
    items.add(op);
    await _persist(items);
  }

  Future<List<SyncOperation>> pending() async {
    final raw = _storage.read<String>(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => SyncOperation.fromJson(Map<String, Object?>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> dequeue(String id) async {
    final items = await pending();
    items.removeWhere((op) => op.id == id);
    await _persist(items);
  }

  Future<int> get pendingCount async => (await pending()).length;

  Future<void> processAll(ApiClient client) async {
    final items = await pending();
    if (items.isEmpty) return;

    // Priority: sos > status_change > location_update
    items.sort((a, b) {
      const priority = {'sos': 0, 'status_change': 1, 'location_update': 2};
      final pa = priority[a.type] ?? 3;
      final pb = priority[b.type] ?? 3;
      if (pa != pb) return pa.compareTo(pb);
      return a.createdAt.compareTo(b.createdAt);
    });

    final failed = <SyncOperation>[];
    for (final op in items) {
      try {
        switch (op.method) {
          case 'POST':
            await client.post(op.endpoint, body: op.body);
          case 'PATCH':
            await client.patch(op.endpoint, body: op.body);
          case 'DELETE':
            await client.delete(op.endpoint, body: op.body);
          default:
            await client.post(op.endpoint, body: op.body);
        }
      } catch (_) {
        failed.add(op);
      }
    }

    await _persist(failed);
  }

  Future<void> _persist(List<SyncOperation> items) async {
    await _storage.write(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
