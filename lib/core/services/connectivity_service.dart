import 'dart:async';
import 'dart:io';

import '../config/env.dart';

enum ConnectivityStatus { online, limited, offline }

enum ActiveBackend { tower, cloud }

class ConnectivityService {
  ConnectivityService();

  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _lastStatus = ConnectivityStatus.offline;
  ActiveBackend _activeBackend = ActiveBackend.cloud;
  Timer? _pollTimer;

  Stream<ConnectivityStatus> get onStatusChanged => _controller.stream;
  ConnectivityStatus get currentStatusSync => _lastStatus;
  ActiveBackend get activeBackend => _activeBackend;

  String get activeApiUrl => _activeBackend == ActiveBackend.tower
      ? Env.towerApiUrl
      : Env.cloudApiUrl;

  String get activeAiUrl => _activeBackend == ActiveBackend.tower
      ? Env.towerAiUrl
      : Env.cloudAiUrl;

  Future<ConnectivityStatus> currentStatus() async {
    final previousBackend = _activeBackend;
    final status = await _checkConnectivity();
    // Emit on a status change (online/limited/offline) OR a backend flip
    // (tower <-> cloud) — staying "online" the whole time while the active
    // backend silently switches would otherwise never notify listeners.
    if (status != _lastStatus || _activeBackend != previousBackend) {
      _lastStatus = status;
      _controller.add(status);
    }
    return status;
  }

  void startMonitoring() {
    _pollTimer?.cancel();
    currentStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await currentStatus();
    });
  }

  bool get supportsOfflineFallback => true;

  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }

  Future<ConnectivityStatus> _checkConnectivity() async {
    // Check both candidates concurrently rather than tower-then-cloud in
    // sequence — this now also runs at app startup, before login, so a
    // sequential 3s+3s worst case would add a very visible delay before the
    // login screen becomes usable.
    final reachability = await Future.wait([
      _canReach(Env.towerApiUrl),
      _canReach(Env.cloudApiUrl),
    ]);
    final towerReachable = reachability[0];
    final cloudReachable = reachability[1];

    // Prefer the local tower when both are reachable — it's the faster,
    // fully-offline-capable path.
    if (towerReachable) {
      _activeBackend = ActiveBackend.tower;
      return ConnectivityStatus.online;
    }

    if (cloudReachable) {
      _activeBackend = ActiveBackend.cloud;
      return ConnectivityStatus.online;
    }

    // Has network interface but neither backend reachable
    if (await _hasNetworkInterface()) {
      return ConnectivityStatus.limited;
    }

    return ConnectivityStatus.offline;
  }

  Future<bool> _canReach(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasNetworkInterface() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.any,
        includeLinkLocal: false,
        includeLoopback: false,
      );
      return interfaces.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
