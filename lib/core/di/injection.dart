import 'package:flutter/widgets.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/prediction_repository.dart';
import '../../data/repositories/rescue_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/sources/local/cache_manager.dart';
import '../../data/sources/local/local_storage.dart';
import '../../data/sources/remote/alerts_api.dart';
import '../../data/sources/remote/auth_api.dart';
import '../../data/sources/remote/family_api.dart';
import '../../data/sources/remote/map_api.dart';
import '../../data/sources/remote/prediction_api.dart';
import '../../data/sources/remote/rescue_api.dart';
import '../../data/sources/remote/teams_api.dart';
import '../config/api_config.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/lora/lora_service.dart';
import '../services/map_service.dart';
import '../services/notification_service.dart';
import '../services/offline/offline_3d_pack_service.dart';
import '../services/offline/offline_data_cache.dart';
import '../services/offline/offline_map_cache.dart';
import '../services/offline/sync_queue.dart';
import '../services/storage_service.dart';
import '../services/tower_socket_service.dart';

Future<AppDependencies> configureDependencies() async {
  final localStorage = await LocalStorage.create();
  final dependencies = AppDependencies(
    apiConfig: Env.apiConfig,
    localStorage: localStorage,
  );

  // Resolve which backend is actually reachable (tower vs cloud) before the
  // login screen can submit anything. Without this, apiClient/aiClient keep
  // whatever base URL was baked in at build time — e.g. the tower IP, which
  // doesn't exist on regular WiFi — and login has no way to recover, since
  // the tower/cloud switch used to only run after a successful login.
  await dependencies.connectivityService.currentStatus();
  dependencies.apiClient.updateBaseUrl(
    dependencies.connectivityService.activeApiUrl,
  );
  dependencies.aiClient.updateBaseUrl(
    dependencies.connectivityService.activeAiUrl,
  );

  dependencies.initialUser = await dependencies.authRepository.restoreSession();
  return dependencies;
}

class AppDependencies {
  AppDependencies({required ApiConfig apiConfig, required this.localStorage})
    : apiClient = ApiClient(config: apiConfig),
      aiClient = ApiClient(config: Env.aiConfig) {
    cacheManager = CacheManager(storage: localStorage);
    storageService = StorageService(localStorage: localStorage);
    connectivityService = ConnectivityService();
    connectivityService.startMonitoring();
    locationService = LocationService();
    notificationService = NotificationService();
    loraService = OfflineLoRaService();
    offlineMapCache = OfflineMapCache(storage: localStorage);
    offline3DPackService = Offline3DPackService(storage: localStorage);
    offlineDataCache = OfflineDataCache(storage: localStorage);
    syncQueue = SyncQueue(storage: localStorage);
    mapService = MapService(offlineMapCache: offlineMapCache);
    towerSocket = TowerSocketService();

    authApi = AuthApi(apiClient);
    alertsApi = AlertsApi(apiClient);
    rescueApi = RescueApi(apiClient);
    mapApi = MapApi(apiClient);
    familyApi = FamilyApi(apiClient);
    predictionApi = PredictionApi(apiClient);
    teamsApi = TeamsApi(apiClient);

    authRepository = AuthRepository(
      remote: authApi,
      storage: storageService,
      connectivity: connectivityService,
    );
    alertRepository = AlertRepository(
      remote: alertsApi,
      connectivityService: connectivityService,
      offlineDataCache: offlineDataCache,
      syncQueue: syncQueue,
    );
    mapRepository = MapRepository(remote: mapApi, mapService: mapService);
    rescueRepository = RescueRepository(
      remote: rescueApi,
      loraService: loraService,
      mapRepository: mapRepository,
      connectivityService: connectivityService,
      offlineDataCache: offlineDataCache,
      syncQueue: syncQueue,
    );
    familyRepository = FamilyRepository(
      remote: familyApi,
      connectivityService: connectivityService,
      offlineDataCache: offlineDataCache,
      syncQueue: syncQueue,
    );
    predictionRepository = PredictionRepository(remote: predictionApi);
    teamRepository = TeamRepository(
      remote: teamsApi,
      connectivityService: connectivityService,
      offlineDataCache: offlineDataCache,
      syncQueue: syncQueue,
    );
    dashboardRepository = DashboardRepository(alertRepository: alertRepository);
  }

  final ApiClient apiClient;
  final ApiClient aiClient;
  UserModel? initialUser;

  final LocalStorage localStorage;
  late final CacheManager cacheManager;
  late final StorageService storageService;
  late final ConnectivityService connectivityService;
  late final LocationService locationService;
  late final NotificationService notificationService;
  late final LoRaService loraService;
  late final OfflineMapCache offlineMapCache;
  late final Offline3DPackService offline3DPackService;
  late final OfflineDataCache offlineDataCache;
  late final SyncQueue syncQueue;
  late final MapService mapService;
  late final TowerSocketService towerSocket;

  late final AuthApi authApi;
  late final AlertsApi alertsApi;
  late final RescueApi rescueApi;
  late final MapApi mapApi;
  late final FamilyApi familyApi;
  late final PredictionApi predictionApi;
  late final TeamsApi teamsApi;

  late final AuthRepository authRepository;
  late final AlertRepository alertRepository;
  late final RescueRepository rescueRepository;
  late final MapRepository mapRepository;
  late final FamilyRepository familyRepository;
  late final PredictionRepository predictionRepository;
  late final TeamRepository teamRepository;
  late final DashboardRepository dashboardRepository;
}

class AppDependenciesScope extends InheritedWidget {
  const AppDependenciesScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppDependenciesScope>();
    assert(
      scope != null,
      'AppDependenciesScope was not found in the widget tree.',
    );
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppDependenciesScope oldWidget) {
    return dependencies != oldWidget.dependencies;
  }
}
