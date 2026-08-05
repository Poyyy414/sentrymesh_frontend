import 'dart:async';
import 'dart:io';

import '../config/env.dart';
import 'backend_health_check.dart';
import 'tower_discovery.dart';

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

  // Register/login/logout need the real cloud specifically, not just "online"
  // — that status is true whenever the tower is reachable too, and an
  // account created against the tower's backend would only ever exist in
  // the tower's own local database, never reaching the cloud on its own.
  // Use a longer timeout than the poll check — the Render free-tier backend
  // can take up to 50 s to cold-start, and we don't want a sleeping server
  // to look like "no internet" on the login screen.
  Future<bool> isCloudReachable() => isSentryMeshBackend(
        Env.cloudApiUrl,
        timeout: const Duration(seconds: 20),
      );

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
    var towerReachable = reachability[0];
    final cloudReachable = reachability[1];

    // The known tower host didn't answer — it may be a different tower
    // device, or this hotspot uses a different gateway convention than
    // last time. Search the current network for one before giving up.
    if (!towerReachable) {
      final uri = Uri.parse(Env.towerApiUrl);
      final discovered = await TowerDiscovery.findHost(
        port: uri.hasPort ? uri.port : 80,
      );
      if (discovered != null) {
        Env.setDiscoveredTowerHost(discovered);
        towerReachable = true;
      }
    }

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

  // A bare TCP connect here used to be enough to call a host "reachable",
  // but that's a false-positive risk for the tower specifically: its
  // candidate address is a network's ".1" gateway, which on plenty of
  // WiFi networks is a router that happens to answer on the same port for
  // something completely unrelated (an admin UI, another dev server,
  // etc). Verifying the actual /health response body confirms this is
  // really the SentryMesh backend, not just something occupying the port.
  Future<bool> _canReach(String url) => isSentryMeshBackend(url);

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
