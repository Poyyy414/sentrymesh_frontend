enum ConnectivityStatus { online, limited, offline }

class ConnectivityService {
  const ConnectivityService();

  Future<ConnectivityStatus> currentStatus() async {
    return ConnectivityStatus.limited;
  }

  bool get supportsOfflineFallback => true;
}
