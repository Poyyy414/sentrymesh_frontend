import 'package:sentrymesh_frontend/core/config/api_config.dart';
import 'package:sentrymesh_frontend/core/di/injection.dart';
import 'package:sentrymesh_frontend/core/services/connectivity_service.dart';
import 'package:sentrymesh_frontend/data/sources/local/local_storage.dart';

import 'fake_http_client.dart';

Future<AppDependencies> configureTestDependencies() async {
  final localStorage = await LocalStorage.create();
  final deps = AppDependencies(
    apiConfig: const ApiConfig(baseUrl: 'http://localhost'),
    localStorage: localStorage,
    httpClient: buildTestHttpClient(),
    testConnectivity: _AlwaysCloudConnectivityService(),
  );
  deps.apiClient.updateBaseUrl('http://localhost');
  deps.aiClient.updateBaseUrl('http://localhost');
  deps.initialUser = await deps.authRepository.restoreSession();
  return deps;
}

class _AlwaysCloudConnectivityService extends ConnectivityService {
  @override
  Future<bool> isCloudReachable() async => true;

  @override
  Future<ConnectivityStatus> currentStatus() async =>
      ConnectivityStatus.online;

  @override
  void startMonitoring() {}
}
