import 'package:flutter/widgets.dart';

import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/prediction_repository.dart';
import '../../data/repositories/rescue_repository.dart';
import '../../data/sources/local/cache_manager.dart';
import '../../data/sources/local/local_storage.dart';
import '../../data/sources/remote/alerts_api.dart';
import '../../data/sources/remote/auth_api.dart';
import '../../data/sources/remote/family_api.dart';
import '../../data/sources/remote/map_api.dart';
import '../../data/sources/remote/prediction_api.dart';
import '../../data/sources/remote/rescue_api.dart';
import '../config/api_config.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/location_service.dart';
import '../services/lora/lora_service.dart';
import '../services/map_service.dart';
import '../services/notification_service.dart';
import '../services/offline/offline_map_cache.dart';
import '../services/storage_service.dart';

Future<AppDependencies> configureDependencies() async {
  return AppDependencies(apiConfig: Env.apiConfig);
}

class AppDependencies {
  AppDependencies({required ApiConfig apiConfig})
    : apiClient = ApiClient(config: apiConfig),
      aiClient = ApiClient(config: Env.aiConfig) {
    localStorage = LocalStorage();
    cacheManager = CacheManager(storage: localStorage);
    storageService = StorageService(localStorage: localStorage);
    connectivityService = ConnectivityService();
    locationService = LocationService();
    notificationService = NotificationService();
    loraService = OfflineLoRaService();
    offlineMapCache = OfflineMapCache(storage: localStorage);
    mapService = MapService(offlineMapCache: offlineMapCache);

    authApi = AuthApi(apiClient);
    alertsApi = AlertsApi(apiClient);
    rescueApi = RescueApi(apiClient);
    mapApi = MapApi(apiClient);
    familyApi = FamilyApi(apiClient);
    predictionApi = PredictionApi(aiClient);

    authRepository = AuthRepository(remote: authApi, storage: storageService);
    alertRepository = AlertRepository(remote: alertsApi);
    rescueRepository = RescueRepository(
      remote: rescueApi,
      loraService: loraService,
    );
    mapRepository = MapRepository(remote: mapApi);
    familyRepository = FamilyRepository(remote: familyApi);
    predictionRepository = PredictionRepository(remote: predictionApi);
    dashboardRepository = DashboardRepository(alertRepository: alertRepository);
  }

  final ApiClient apiClient;
  final ApiClient aiClient;

  late final LocalStorage localStorage;
  late final CacheManager cacheManager;
  late final StorageService storageService;
  late final ConnectivityService connectivityService;
  late final LocationService locationService;
  late final NotificationService notificationService;
  late final LoRaService loraService;
  late final OfflineMapCache offlineMapCache;
  late final MapService mapService;

  late final AuthApi authApi;
  late final AlertsApi alertsApi;
  late final RescueApi rescueApi;
  late final MapApi mapApi;
  late final FamilyApi familyApi;
  late final PredictionApi predictionApi;

  late final AuthRepository authRepository;
  late final AlertRepository alertRepository;
  late final RescueRepository rescueRepository;
  late final MapRepository mapRepository;
  late final FamilyRepository familyRepository;
  late final PredictionRepository predictionRepository;
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
