import 'dart:io';

import 'backend_health_check.dart';

/// Finds the tower on the local network without relying on one hardcoded
/// address. Hotspot hosts — regardless of implementation (Linux
/// NetworkManager, Android tethering, iOS Personal Hotspot, Windows Mobile
/// Hotspot) — near-universally self-assign the ".1" address of whatever
/// subnet they create. So instead of assuming a single fixed IP, this
/// derives that candidate from the phone's own address on each active
/// network interface, then verifies which one (if any) actually answers.
class TowerDiscovery {
  const TowerDiscovery._();

  static Future<String?> findHost({
    required int port,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    for (final host in await _candidateHosts()) {
      // ".1" is also just "the router" on plenty of WiFi networks, and
      // routers commonly answer on arbitrary ports for their own admin UI
      // or other unrelated services — a bare TCP connect used to be
      // enough to falsely "discover" one of those as the tower.
      if (await isSentryMeshBackend('http://$host:$port', timeout: timeout)) {
        return host;
      }
    }
    return null;
  }

  static Future<List<String>> _candidateHosts() async {
    final hosts = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            hosts.add('${parts[0]}.${parts[1]}.${parts[2]}.1');
          }
        }
      }
    } catch (_) {
      // Best-effort — no usable interfaces found.
    }
    return hosts.toList();
  }
}
