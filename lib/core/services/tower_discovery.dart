import 'dart:io';

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
      if (await _canReach(host, port, timeout)) {
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

  static Future<bool> _canReach(
    String host,
    int port,
    Duration timeout,
  ) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
