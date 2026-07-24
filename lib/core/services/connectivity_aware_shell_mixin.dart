import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../di/injection.dart';
import 'connectivity_service.dart';

/// Shared connectivity-monitoring behavior for top-level shells (resident,
/// responder, admin): switches the API/AI base URL and reconnects the live
/// socket whenever the active backend changes, and flushes the offline sync
/// queue when it does.
///
/// This exists because the same logic was independently copy-pasted into
/// each shell and drifted out of sync — a real bug shipped where two of the
/// three shells got a fix (tracking the active backend directly, since
/// ConnectivityStatus.online covers both tower and cloud so a same-status
/// backend flip was otherwise invisible) while the third never did. Putting
/// it in one place means a future fix like that lands everywhere at once.
mixin ConnectivityAwareShellMixin<T extends StatefulWidget> on State<T> {
  ConnectivityStatus connectivity = ConnectivityStatus.online;
  ActiveBackend? _lastActiveBackend;
  int pendingQueueCount = 0;
  bool _isSyncing = false;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  /// Override to refresh whatever repositories this shell cares about once
  /// a sync-queue flush completes. Best-effort — errors here don't block
  /// reporting sync completion.
  Future<void> onSyncCompleted() async {}

  void setupConnectivityMonitor() {
    final deps = AppDependenciesScope.of(context);
    deps.connectivityService.currentStatus().then((status) async {
      if (!mounted) return;
      setState(() => connectivity = status);
      // The service may have already resolved tower-vs-cloud and fired its
      // one status-change event before this listener subscribed (broadcast
      // streams don't replay), so apply the resolved backend explicitly here
      // instead of waiting for a future change that may never come.
      switchBackendIfNeeded();
      reconnectSocket();
      if (status == ConnectivityStatus.online) {
        await syncQueuedOperations();
      }
      _lastActiveBackend = deps.connectivityService.activeBackend;
    });
    updatePendingCount();

    _connectivitySub = deps.connectivityService.onStatusChanged.listen((
      status,
    ) {
      if (!mounted) return;
      final wasOffline = connectivity != ConnectivityStatus.online;
      // Tower and cloud both count as ConnectivityStatus.online, so
      // wasOffline alone misses the tower -> cloud handover — the exact
      // moment queued writes actually need to reach the real backend.
      final newBackend = deps.connectivityService.activeBackend;
      final backendFlippedToCloud =
          _lastActiveBackend == ActiveBackend.tower &&
          newBackend == ActiveBackend.cloud;
      setState(() => connectivity = status);

      switchBackendIfNeeded();
      if ((wasOffline || backendFlippedToCloud) &&
          status == ConnectivityStatus.online) {
        syncQueuedOperations();
        reconnectSocket();
      }
      _lastActiveBackend = newBackend;
      updatePendingCount();
    });
  }

  void disposeConnectivityMonitor() {
    _connectivitySub?.cancel();
  }

  void switchBackendIfNeeded() {
    final deps = AppDependenciesScope.of(context);
    final cs = deps.connectivityService;
    deps.apiClient.updateBaseUrl(cs.activeApiUrl);
    deps.aiClient.updateBaseUrl(cs.activeAiUrl);
  }

  void reconnectSocket() {
    final deps = AppDependenciesScope.of(context);
    final user = deps.initialUser;
    if (user != null) {
      deps.towerSocket.reconnect(
        role: user.role,
        userId: user.id,
        token: deps.storageService.readAuthToken(),
        baseUrl: deps.connectivityService.activeApiUrl,
      );
    }
  }

  Future<void> updatePendingCount() async {
    final deps = AppDependenciesScope.of(context);
    final count = await deps.syncQueue.pendingCount;
    if (mounted) setState(() => pendingQueueCount = count);
  }

  // The initial currentStatus() check and the onStatusChanged stream can
  // both resolve "online" close together at startup — without this guard
  // that would fire processAll() twice concurrently and could resend the
  // same queued operation before either call persists the emptied queue.
  Future<void> syncQueuedOperations() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _doSyncQueuedOperations();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _doSyncQueuedOperations() async {
    final deps = AppDependenciesScope.of(context);
    final count = await deps.syncQueue.pendingCount;
    if (count == 0) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Syncing $count queued operations...'),
          backgroundColor: AppTheme.signalBlue,
        ),
      );
    }

    await deps.syncQueue.processAll(deps.apiClient);
    await updatePendingCount();

    try {
      await onSyncCompleted();
    } catch (_) {
      // Best-effort refresh — sync itself already succeeded.
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data synced'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
    }
  }
}
