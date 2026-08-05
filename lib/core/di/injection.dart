import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../data/models/user_model.dart';
import '../../data/repositories/alert_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/map_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/prediction_repository.dart';
import '../../data/repositories/rescue_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/sources/local/cache_manager.dart';
import '../../data/sources/local/local_storage.dart';
import '../../data/sources/remote/alerts_api.dart';
import '../../data/sources/remote/auth_api.dart';
import '../../data/sources/remote/family_api.dart';
import '../../data/sources/remote/map_api.dart';
import '../../data/sources/remote/notifications_api.dart';
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
import '../services/sms_service.dart';
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
  await dependencies.notificationService.initialize();
  return dependencies;
}

class AppDependencies {
  AppDependencies({
    required ApiConfig apiConfig,
    required this.localStorage,
    http.Client? httpClient,
    ConnectivityService? testConnectivity,
  }) : apiClient = ApiClient(config: apiConfig, client: httpClient),
       aiClient = ApiClient(config: Env.aiConfig, client: httpClient) {
    cacheManager = CacheManager(storage: localStorage);
    storageService = StorageService(localStorage: localStorage);
    connectivityService = testConnectivity ?? ConnectivityService();
    connectivityService.startMonitoring();
    locationService = LocationService();
    notificationService = NotificationService();
    smsService = SmsService();
    syncQueue = SyncQueue(storage: localStorage);
    loraService = OfflineLoRaService(syncQueue: syncQueue);
    offlineMapCache = OfflineMapCache(storage: localStorage);
    offline3DPackService = Offline3DPackService(storage: localStorage);
    offlineDataCache = OfflineDataCache(storage: localStorage);
    mapService = MapService(offlineMapCache: offlineMapCache);
    towerSocket = TowerSocketService();
    _wireNotifications();
    _startLocationReporting();

    authApi = AuthApi(apiClient);
    alertsApi = AlertsApi(apiClient);
    rescueApi = RescueApi(apiClient);
    mapApi = MapApi(apiClient);
    familyApi = FamilyApi(apiClient);
    notificationsApi = NotificationsApi(apiClient);
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
    notificationRepository = NotificationRepository(remote: notificationsApi);
    predictionRepository = PredictionRepository(remote: predictionApi);
    teamRepository = TeamRepository(
      remote: teamsApi,
      connectivityService: connectivityService,
      offlineDataCache: offlineDataCache,
      syncQueue: syncQueue,
    );
    dashboardRepository = DashboardRepository(alertRepository: alertRepository);
  }

  // Fires a system notification-tray alert for every safety-critical socket
  // event, regardless of which screen (if any) is currently on top, since
  // the socket stays connected for the whole app session rather than just
  // while a particular screen is mounted. This isn't gated by role on the
  // client — the server already scopes each event to the right audience via
  // socket rooms (residents get hazard:warning + their own sos:status;
  // responders get sos:new/sos:assigned; a specific team gets its own
  // team:assignment), so whichever of these actually arrives on this
  // connection is, by construction, relevant to whoever is logged in.
  void _wireNotifications() {
    towerSocket.onHazardWarning.listen((data) {
      notificationService.showLocalAlert(
        title: data['title']?.toString() ?? 'Hazard Warning',
        message:
            data['message']?.toString() ??
            'A hazard has been detected in your area.',
      );
    });

    towerSocket.onSosStatus.listen((data) {
      final message = switch (data['status']?.toString()) {
        'acknowledged' =>
          'A responder team has been dispatched to your location!',
        'inProgress' => 'Responder is on the way to your location!',
        'resolved' => 'Your rescue request has been resolved.',
        _ => null,
      };
      if (message != null) {
        notificationService.showLocalAlert(
          title: 'Rescue Request Update',
          message: message,
        );
      }
    });

    towerSocket.onSosNew.listen((data) {
      final emergencyType = data['emergency_type']?.toString() ?? 'Unknown';
      final peopleNeedingHelp =
          int.tryParse(data['people_needing_help']?.toString() ?? '') ?? 1;
      notificationService.showLocalAlert(
        title: 'New SOS Request',
        message:
            '$emergencyType emergency — $peopleNeedingHelp '
            '${peopleNeedingHelp == 1 ? 'person' : 'people'} needing help.',
      );
    });

    towerSocket.onSosAssigned.listen((data) {
      notificationService.showLocalAlert(
        title: 'Rescue Request Dispatched',
        message: 'A rescue request was just assigned to a response team.',
      );
    });

    towerSocket.onTeamAssignment.listen((data) {
      final teamName = data['assigned_team_name']?.toString() ?? 'your team';
      notificationService.showLocalAlert(
        title: 'Team Assignment',
        message: 'New SOS assigned to Team $teamName.',
      );
    });

    towerSocket.onTyphoonAlert.listen((data) {
      final signal = data['signal']?.toString() ?? '?';
      final event = data['event']?.toString() ?? 'Tropical cyclone';
      final locationLabel = data['location_label']?.toString();
      notificationService.showLocalAlert(
        title: 'Typhoon Alert — Signal $signal',
        message: locationLabel != null
            ? '$event near $locationLabel.'
            : '$event is affecting your monitored area.',
      );
    });

    towerSocket.onFamilyStatusUpdate.listen((data) {
      final name = data['name']?.toString() ?? 'A family member';
      final message = switch (data['status']?.toString()) {
        'safe' => '$name marked themselves as safe.',
        'need_help' => '$name needs help!',
        _ => '$name\'s status is unknown.',
      };
      notificationService.showLocalAlert(
        title: 'Family Safety Update',
        message: message,
      );
    });

    towerSocket.onFamilyInvite.listen((data) {
      final fromName = data['from_name']?.toString() ?? 'Someone';
      notificationService.showLocalAlert(
        title: 'Family Invite',
        message: '$fromName added you as a family member. Open Messages to '
            'accept or decline.',
      );
    });

    towerSocket.onFamilyInviteAccepted.listen((data) {
      final name = data['name']?.toString() ?? 'Someone';
      notificationService.showLocalAlert(
        title: 'Family Invite Accepted',
        message: '$name accepted your family invite.',
      );
    });
  }

  // Reports this device's live location to the server so hazard/typhoon
  // broadcasts can be scoped to people actually nearby instead of reaching
  // every connected device regardless of distance. watchLocation() only
  // fires on real movement (10m+), so this is cheap to leave running for
  // the whole app session. Permission/GPS failures are silently ignored,
  // same as the existing location-update pattern elsewhere in the app —
  // worst case the server falls back to notifying this device anyway.
  void _startLocationReporting() {
    locationService.watchLocation().listen(
      (point) => towerSocket.emitMyLocation(point.latitude, point.longitude),
      onError: (_) {},
    );
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
  late final SmsService smsService;
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
  late final NotificationsApi notificationsApi;
  late final PredictionApi predictionApi;
  late final TeamsApi teamsApi;

  late final AuthRepository authRepository;
  late final AlertRepository alertRepository;
  late final RescueRepository rescueRepository;
  late final MapRepository mapRepository;
  late final FamilyRepository familyRepository;
  late final NotificationRepository notificationRepository;
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
