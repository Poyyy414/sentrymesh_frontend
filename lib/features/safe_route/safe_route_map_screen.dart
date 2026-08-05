import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/config/map_tile_config.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/location_service.dart';
import '../../core/services/tower_socket_service.dart';
import '../../core/widgets/offline_map_download_button.dart';
import '../../data/models/evacuation_center_model.dart';
import '../../data/models/hazard_zone_model.dart';
import '../../data/models/route_model.dart';
import '../../data/models/team_model.dart';
import '../responder/widgets/auto_3d_pack_download.dart';
import 'state/asean_country.dart';
import 'state/turn_by_turn.dart';
import 'widgets/evacuation_center_sheet.dart';
import 'widgets/map_view.dart';
import 'widgets/resident_map_3d_view.dart';
import 'widgets/turn_by_turn_overlay.dart';

class SafeRouteMapScreen extends StatefulWidget {
  const SafeRouteMapScreen({this.autoRouteToNearest = false, super.key});

  // True only when this screen was opened from an active hazard warning
  // (e.g. "View Evacuation Routes" on the warning dialog) - the only two
  // ways the safe path is allowed to appear are that, or the user manually
  // tapping a specific evacuation center and hitting "Navigate here".
  final bool autoRouteToNearest;

  @override
  State<SafeRouteMapScreen> createState() => _SafeRouteMapScreenState();
}

class _SafeRouteMapScreenState extends State<SafeRouteMapScreen> {
  final _locationService = const LocationService();

  AseanCountry _selectedCountry = AseanCountry.defaultCountry;
  GeoPoint? _userLocation;
  bool _isLocating = false;
  MapLayerVisibility _layers = const MapLayerVisibility();
  double _rainfallMmPh = 0.0;
  bool _showLayerPanel = false;
  bool _guidanceActive = false;
  Timer? _guidanceTimer;
  StreamSubscription<GeoPoint>? _liveLocationSub;
  DateTime? _lastRouteFetchTime;
  bool _isCenteredOnUser = true;

  List<EvacuationCenterModel> _evacuationCenters = [];
  List<TeamModel> _teamLocations = [];
  EvacuationCenterModel? _selectedCenter;
  RouteModel? _routeToCenter;
  bool _isCalculatingRoute = false;
  bool _hasAutoLocated = false;
  StreamSubscription<JsonMap>? _evacuationCenterUpdateSub;
  StreamSubscription<JsonMap>? _hazardWarningSub;
  Timer? _mapConnectivityTimer;
  // Gated off - _handleToggle3D shows a "coming soon" dialog instead of
  // ever flipping this. Kept (rather than deleted outright) so re-enabling
  // 3D later is a one-line change once the guidance-time freeze in
  // resident_map_3d_view.dart is actually resolved.
  final bool _use3D = false;
  bool _has3DPackReady = false;
  // Keyed by evacuation center id so a repeat broadcast for the same
  // center updates in place instead of piling up duplicate zones - each
  // broadcast covers one monitored center, not a batch.
  final Map<String, HazardZone> _hazardZonesByCenterId = {};
  List<TurnStep> _turnSteps = [];
  double? _guidanceSpeedKmh;
  GeoPoint? _lastGuidanceLocation;
  DateTime? _lastGuidanceLocationTime;

  bool get _isDaytime {
    final h = DateTime.now().hour;
    return h >= 6 && h < 20;
  }

  @override
  void initState() {
    super.initState();
    // MapTileConfig.checkConnectivity() only ever runs once at app startup
    // (main.dart) by default - if that single check happened to fail (e.g.
    // ran before mobile data/Wi-Fi was fully up), this screen would render
    // the plain OpenStreetMap fallback instead of Mapbox's tiles for the
    // rest of the session, even after real internet becomes available.
    // sentry_mesh_shell.dart already re-checks periodically, but this
    // screen is kept as a `const` tab inside its IndexedStack, so the
    // shell rebuilding doesn't actually re-run this screen's own build() -
    // re-checking here directly is what actually makes the tile layer
    // pick up the corrected source.
    _refreshMapTileConnectivity();
    // AppDependenciesScope.of(context) needs a frame to have passed before
    // inherited-widget lookups are safe to make, unlike the plain static
    // MapTileConfig call above - matching the same postFrameCallback pattern
    // already used for this on the responder side.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check3DPackReady();
    });
    _mapConnectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshMapTileConnectivity();
      _check3DPackReady();
    });
  }

  Future<void> _refreshMapTileConnectivity() async {
    await MapTileConfig.checkConnectivity();
    if (mounted) setState(() {});
  }

  bool get _can3D => MapTileConfig.isOnline || _has3DPackReady;

  // Also silently extends 3D offline coverage to wherever the resident
  // currently is, Wi-Fi only - matching the exact same pattern already
  // proven on the responder side.
  Future<void> _check3DPackReady() async {
    if (!mounted) return;
    GeoPoint? location = _userLocation;
    if (location == null) {
      try {
        location = await _locationService.currentLocation();
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;
    await maybeAutoDownload3DPack(context: context, location: location);
    if (!mounted) return;
    final ready = await AppDependenciesScope.of(
      context,
    ).offline3DPackService.hasPackReady(location);
    if (mounted) setState(() => _has3DPackReady = ready);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchWeather();
    _fetchEvacuationCenters();
    _fetchTeamLocations();
    // Silently find the user's own position so the blue dot is there right
    // away - this does NOT draw a route (see _locateUser's autoRouteToNearest
    // gate). Guarded to run once per screen instance so switching tabs back
    // and forth doesn't keep re-triggering a location prompt.
    if (!_hasAutoLocated) {
      _hasAutoLocated = true;
      _locateUser(silent: true);
    }
    // Occupancy/status a responder updates on the ground would otherwise
    // only show up if this screen were reopened - refetch the full list
    // instead of trying to patch a single center in place, since it's a
    // small dataset and avoids the list ever drifting out of sync.
    _evacuationCenterUpdateSub ??= AppDependenciesScope.of(context)
        .towerSocket
        .onEvacuationCenterUpdate
        .listen((_) => _fetchEvacuationCenters());
    // Flood/landslide risk zones - reuses the same hazard:warning broadcast
    // that already triggers the tray notification and Home's warning
    // dialog, rather than inventing a new endpoint. Each event covers one
    // monitored evacuation center at HIGH/CRITICAL risk; a center that
    // drops back below that threshold naturally stops re-broadcasting, but
    // won't be explicitly cleared here without a full refetch - acceptable
    // since these are rare, short-lived events in practice.
    _hazardWarningSub ??= AppDependenciesScope.of(context)
        .towerSocket
        .onHazardWarning
        .listen((data) {
      final zone = HazardZone.fromSocketPayload(data);
      if (zone != null && mounted) {
        setState(() => _hazardZonesByCenterId[zone.centerId] = zone);
      }
    });
  }

  Future<void> _fetchEvacuationCenters() async {
    try {
      final deps = AppDependenciesScope.of(context);
      final centers = await deps.rescueRepository.fetchEvacuationCenters();
      if (mounted) setState(() => _evacuationCenters = centers);
    } catch (_) {}
  }

  Future<void> _fetchTeamLocations() async {
    try {
      final deps = AppDependenciesScope.of(context);
      final teams = await deps.teamRepository.fetchAllTeamsWithLocations();
      if (mounted) setState(() => _teamLocations = teams);
    } catch (_) {}
  }

  Future<void> _calculateRouteToCenter(EvacuationCenterModel center) async {
    final userLoc = _userLocation;
    if (userLoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locate yourself first to calculate route')),
      );
      return;
    }

    setState(() {
      _selectedCenter = center;
      _isCalculatingRoute = true;
    });

    try {
      final deps = AppDependenciesScope.of(context);
      final route = await deps.mapRepository.fetchSafeRoute(
        origin: userLoc,
        destination: center.point,
      );
      if (!mounted) return;
      setState(() {
        _routeToCenter = route;
        _turnSteps = computeTurnSteps(route?.waypoints ?? const []);
        _isCalculatingRoute = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not calculate route')),
        );
      }
    }
  }

  void _autoSelectNearestCenter() {
    final userLoc = _userLocation;
    if (userLoc == null || _evacuationCenters.isEmpty) return;

    final openCenters =
        _evacuationCenters.where((c) => c.isOpen && c.availableSlots > 0).toList();
    if (openCenters.isEmpty) return;

    EvacuationCenterModel? nearest;
    double nearestDist = double.infinity;
    for (final center in openCenters) {
      final dist = _haversineKm(userLoc, center.point);
      if (dist < nearestDist) {
        nearest = center;
        nearestDist = dist;
      }
    }

    if (nearest != null) {
      _calculateRouteToCenter(nearest);
    }
  }

  double _haversineKm(GeoPoint a, GeoPoint b) {
    const r = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;


  Future<void> _fetchWeather() async {
    try {
      final deps = AppDependenciesScope.of(context);
      final lat = _userLocation?.latitude ?? _selectedCountry.latitude;
      final lon = _userLocation?.longitude ?? _selectedCountry.longitude;
      final result = await deps.apiClient.get(
        ApiEndpoints.weatherCurrent,
        queryParameters: {
          'latitude': lat.toString(),
          'longitude': lon.toString(),
        },
      );
      final w = result['weather'];
      if (w is Map) {
        final rain = w['rain'];
        double mm = 0.0;
        if (rain is Map) {
          final v = rain['1h'];
          if (v is num) mm = v.toDouble();
        } else if (rain is num) {
          mm = rain.toDouble();
        }
        if (mounted) setState(() => _rainfallMmPh = mm);
      }
    } catch (_) {
      // Weather is decorative — fail silently
    }
  }

  @override
  void dispose() {
    _guidanceTimer?.cancel();
    _liveLocationSub?.cancel();
    _evacuationCenterUpdateSub?.cancel();
    _hazardWarningSub?.cancel();
    _mapConnectivityTimer?.cancel();
    super.dispose();
  }

  // 3D navigation (route line, live location, turn-by-turn) is gated off
  // for now: getting there took an upstream mapbox_maps_flutter icon-
  // rendering bug fix plus a native SDK version bump, and even after
  // that a guidance-time freeze remains unresolved (see resident_map_3d_view.dart
  // history). Rather than ship a mode that can lock up mid-navigation,
  // this tells residents it's on the way and keeps effort on the 2D map,
  // which is the one that actually needs to be reliable for wayfinding.
  void _handleToggle3D() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.view_in_ar_rounded, color: AppTheme.signalBlue),
        title: const Text('3D map coming soon'),
        content: const Text(
          'The tilted 3D view with turn-by-turn navigation is still being '
          'polished. The 2D map below has everything you need to find a '
          'safe route right now, including live location tracking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _toggleGuidance() {
    if (_guidanceActive) {
      _stopGuidance();
    } else {
      _startGuidance();
    }
  }

  void _startGuidance() {
    setState(() => _guidanceActive = true);
    // _calculateRouteToCenter already fetched the route the resident is
    // guiding on - that counts as "just fetched" for staleness purposes.
    _lastRouteFetchTime = DateTime.now();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Guidance started. Follow the highlighted safe path.'),
      ),
    );
    // The blue dot needs to move as the resident actually moves, not just
    // every 5 seconds - watchLocation() is a continuous, distance-filtered
    // stream (see LocationService), so it fires far more responsively than
    // a fixed timer ever could.
    _liveLocationSub?.cancel();
    _liveLocationSub = _locationService.watchLocation().listen(
      _onLiveGuidanceLocation,
    );
    // Checked every 5s, but only actually hits the routing backend when
    // _maybeRefreshRoute decides it's warranted (drifted off-route, or the
    // route's gone stale) - see that method for why a blind refetch on
    // every tick was wasteful.
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _maybeRefreshRoute(),
    );
  }

  // A resident walking straight down the suggested path doesn't need a
  // fresh route from the backend every 5 seconds - the path they're on is
  // still correct. Only worth the network call when they've actually
  // drifted off it (missed a turn, took a shortcut) or the route's old
  // enough that conditions (new hazards, a closed road) might have moved
  // on without them.
  static const _rerouteDriftMeters = 40.0;
  static const _routeMaxStaleness = Duration(seconds: 60);

  Future<void> _maybeRefreshRoute() async {
    if (!_guidanceActive || !mounted) return;
    final location = _userLocation;
    final route = _routeToCenter;
    if (location == null) return;

    final driftedOff = route == null ||
        route.waypoints.length < 2 ||
        distanceToRouteMeters(location, route.waypoints) >
            _rerouteDriftMeters;
    final stale = _lastRouteFetchTime == null ||
        DateTime.now().difference(_lastRouteFetchTime!) >
            _routeMaxStaleness;

    if (driftedOff || stale) {
      await _refreshGuidanceRoute();
      _lastRouteFetchTime = DateTime.now();
    }
  }

  void _stopGuidance() {
    _guidanceTimer?.cancel();
    _guidanceTimer = null;
    _liveLocationSub?.cancel();
    _liveLocationSub = null;
    _lastGuidanceLocation = null;
    _lastGuidanceLocationTime = null;
    setState(() {
      _guidanceActive = false;
      _guidanceSpeedKmh = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guidance stopped')),
    );
  }

  void _onLiveGuidanceLocation(GeoPoint location) {
    if (!_guidanceActive || !mounted) return;

    // Derived from two consecutive guidance fixes rather than GeoPoint's
    // own speedMps (raw GPS instantaneous speed can be noisy/zero right as
    // movement starts) - this smooths over one extra fix's worth of noise
    // and is what the HUD has been showing, so left as-is.
    final now = DateTime.now();
    final previousLocation = _lastGuidanceLocation;
    final previousTime = _lastGuidanceLocationTime;
    double? speedKmh;
    if (previousLocation != null && previousTime != null) {
      final seconds = now.difference(previousTime).inMilliseconds / 1000;
      if (seconds > 0) {
        final meters = haversineMeters(previousLocation, location);
        speedKmh = (meters / seconds) * 3.6;
      }
    }
    _lastGuidanceLocation = location;
    _lastGuidanceLocationTime = now;

    setState(() {
      _userLocation = location;
      if (speedKmh != null) _guidanceSpeedKmh = speedKmh;
      // _maybeRefreshRoute only hits the backend on actual drift/staleness
      // now, so the turn-by-turn card needs to keep itself current between
      // those refetches: advance past any step effectively reached (so the
      // next instruction takes over instead of showing a growing distance
      // to a turn already behind us), then refresh the now-current step's
      // distance via straight-line distance to its point - a good enough
      // stand-in for remaining road distance over one short leg.
      const arrivalThresholdMeters = 20.0;
      var steps = _turnSteps;
      while (steps.length > 1 &&
          haversineMeters(location, steps.first.point) <
              arrivalThresholdMeters) {
        steps = steps.sublist(1);
      }
      if (steps.isNotEmpty) {
        final current = steps.first;
        steps = [
          TurnStep(
            maneuver: current.maneuver,
            point: current.point,
            legDistanceMeters: haversineMeters(location, current.point),
          ),
          ...steps.skip(1),
        ];
      }
      _turnSteps = steps;
    });
  }

  Future<void> _refreshGuidanceRoute() async {
    if (!_guidanceActive || !mounted) return;
    final location = _userLocation;
    if (location == null) return;
    try {
      // Recalculate route from current position if a center is selected -
      // this also keeps the turn-by-turn steps current, since the fresh
      // route's first leg IS "distance from here to the next turn".
      if (_selectedCenter != null) {
        final deps = AppDependenciesScope.of(context);
        final route = await deps.mapRepository.fetchSafeRoute(
          origin: location,
          destination: _selectedCenter!.point,
        );
        if (mounted && _guidanceActive) {
          setState(() {
            _routeToCenter = route;
            _turnSteps = computeTurnSteps(route?.waypoints ?? const []);
          });
        }
      }
    } catch (_) {
      // Silently continue — guidance keeps running with last known location
    }
  }

  // The safe path is deliberately NOT drawn just because the user's
  // position was found - it only appears when the user manually taps an
  // evacuation center marker and hits "Navigate here" (see _showCenterSheet)
  // or when this screen is opened from an active hazard warning
  // (autoRouteToNearest). Auto-calculating a route on every plain map open
  // was tried and reverted: it drew a path the user didn't ask for.
  //
  // [silent]: used for the automatic locate-on-open - skips permission/
  // error snackbars so simply switching to this tab doesn't immediately
  // interrupt with a dialog before the user has done anything.
  Future<void> _locateUser({bool silent = false}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final location = await _locationService.currentLocation();
      if (!mounted) return;
      setState(() => _userLocation = location);
      _fetchWeather();
      if (widget.autoRouteToNearest) {
        _autoSelectNearestCenter();
      }
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS locked.')),
        );
      }
    } on LocationServiceDisabledException {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Turn on device location to use live routing'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: _locationService.openLocationSettings,
          ),
        ),
      );
    } on LocationPermissionPermanentlyDeniedException {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Allow location access in app settings'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: _locationService.openAppSettings,
          ),
        ),
      );
    } on LocationPermissionDeniedException {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission was denied')),
      );
    } catch (_) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location unavailable. You can still view the map.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: _locationService.openLocationSettings,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────
          Positioned.fill(
            child: _use3D && _can3D
                ? ResidentMap3DView(
                    userLocation: _userLocation,
                    route: _routeToCenter,
                    evacuationCenters: _evacuationCenters,
                    teamLocations: _teamLocations,
                    hazardZones: _hazardZonesByCenterId.values.toList(),
                    selectedCenterId: _selectedCenter?.id,
                    onEvacuationCenterTap: (center) {
                      _showCenterSheet(center);
                    },
                  )
                : MapView(
                    country: _selectedCountry,
                    userLocation: _userLocation,
                    layers: _layers,
                    route: _routeToCenter,
                    isDaytime: _isDaytime,
                    rainfallMmPh: _rainfallMmPh,
                    evacuationCenters: _evacuationCenters,
                    teamLocations: _teamLocations,
                    hazardZones: _hazardZonesByCenterId.values.toList(),
                    selectedCenterId: _selectedCenter?.id,
                    onEvacuationCenterTap: (center) {
                      _showCenterSheet(center);
                    },
                    onCenteredChanged: (centered) =>
                        setState(() => _isCenteredOnUser = centered),
                  ),
          ),

          // ── Top bar: compact overlay, or turn-by-turn HUD while guiding
          // (bottom stays on _RouteSummaryCard even in 2D - see the note
          // near TurnByTurnSummaryBar below on why that one's still 3D-only) ──
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: _guidanceActive
                ? TurnByTurnInstructionCard(
                    currentStep: _turnSteps.isNotEmpty ? _turnSteps.first : null,
                    nextStep: _turnSteps.length > 1 ? _turnSteps[1] : null,
                  )
                : _TopBar(
                    selectedCountry: _selectedCountry,
                    isDaytime: _isDaytime,
                    rainfallMmPh: _rainfallMmPh,
                    showLayers: _showLayerPanel,
                    onToggleLayers: () =>
                        setState(() => _showLayerPanel = !_showLayerPanel),
                    onCountryChanged: (c) => setState(() {
                      _selectedCountry = c;
                      _userLocation = null;
                      _fetchWeather();
                    }),
                    use3D: _use3D,
                    can3D: _can3D,
                    onToggle3D: _handleToggle3D,
                  ),
          ),

          // ── Layer toggle panel ───────────────────────────────────────
          if (_showLayerPanel && !_guidanceActive)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 72,
              left: 12,
              right: 12,
              child: _LayerPanel(
                layers: _layers,
                onChanged: (l) => setState(() => _layers = l),
              ),
            ),

          // ── Locate FAB ───────────────────────────────────────────────
          Positioned(
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: _LocateFab(
              isLoading: _isLocating,
              hasLocation: _userLocation != null,
              isCenteredOnUser: _isCenteredOnUser,
              guidanceActive: _guidanceActive,
              onPressed: _locateUser,
              onToggleGuidance: _toggleGuidance,
            ),
          ),

          // ── Download offline maps FAB ────────────────────────────────
          Positioned(
            left: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: OfflineMapDownloadButton(
              center:
                  _userLocation ??
                  GeoPoint(
                    latitude: _selectedCountry.latitude,
                    longitude: _selectedCountry.longitude,
                  ),
            ),
          ),

          // ── Route summary card, or turn-by-turn summary while guiding
          // in 3D ──
          if (_use3D && _guidanceActive && _routeToCenter != null)
            Positioned(
              left: 14,
              right: 80,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: TurnByTurnSummaryBar(
                speedKmh: _guidanceSpeedKmh,
                remainingDistanceKm: _routeToCenter!.distanceKm,
                etaMinutes: _routeToCenter!.estimatedMinutes,
                onStop: _stopGuidance,
              ),
            )
          else if (_routeToCenter != null && _selectedCenter != null)
            Positioned(
              left: 14,
              right: 80,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: _RouteSummaryCard(
                route: _routeToCenter!,
                centerName: _selectedCenter!.name,
                isCalculating: _isCalculatingRoute,
                onStartGuidance: _toggleGuidance,
                guidanceActive: _guidanceActive,
                onClear: () => setState(() {
                  _routeToCenter = null;
                  _selectedCenter = null;
                  _turnSteps = [];
                  if (_guidanceActive) _stopGuidance();
                }),
              ),
            )
          else
            // ── Weather badge (bottom-left) ────────────────────────────
            Positioned(
              left: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: _WeatherBadge(
                isDaytime: _isDaytime,
                rainfallMmPh: _rainfallMmPh,
              ),
            ),
        ],
      ),
    );
  }

  void _showCenterSheet(EvacuationCenterModel center) {
    final dist = _userLocation != null
        ? _haversineKm(_userLocation!, center.point)
        : null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => EvacuationCenterSheet(
        center: center,
        distanceKm: dist,
        onNavigate: () {
          Navigator.of(context).pop();
          _calculateRouteToCenter(center);
        },
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.selectedCountry,
    required this.isDaytime,
    required this.rainfallMmPh,
    required this.showLayers,
    required this.onToggleLayers,
    required this.onCountryChanged,
    required this.use3D,
    required this.can3D,
    required this.onToggle3D,
  });

  final AseanCountry selectedCountry;
  final bool isDaytime;
  final double rainfallMmPh;
  final bool showLayers;
  final VoidCallback onToggleLayers;
  final ValueChanged<AseanCountry> onCountryChanged;
  final bool use3D;
  final bool can3D;
  final VoidCallback onToggle3D;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Country picker
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            elevation: 3,
            child: DropdownButtonFormField<AseanCountry>(
              initialValue: selectedCountry,
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.public_rounded, size: 19),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: AseanCountry.countries
                  .map(
                    (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (c) {
                if (c != null) onCountryChanged(c);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 3D toggle button
        Material(
          color: use3D ? AppTheme.signalBlue : Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: IconButton(
            tooltip: can3D
                ? (use3D ? 'Switch to 2D map' : 'Switch to 3D map')
                : '3D view needs a connection or an offline 3D map',
            onPressed: can3D ? onToggle3D : null,
            icon: Icon(
              use3D ? Icons.map_rounded : Icons.view_in_ar_rounded,
              color: !can3D
                  ? Theme.of(context).disabledColor
                  : use3D
                      ? Colors.white
                      : AppTheme.navy,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Layer toggle button
        Material(
          color: showLayers ? AppTheme.signalBlue : Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: IconButton(
            tooltip: 'Map layers',
            onPressed: onToggleLayers,
            icon: Icon(
              Icons.layers_rounded,
              color: showLayers ? Colors.white : AppTheme.navy,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Layer panel ────────────────────────────────────────────────────────────

class _LayerPanel extends StatelessWidget {
  const _LayerPanel({required this.layers, required this.onChanged});

  final MapLayerVisibility layers;
  final ValueChanged<MapLayerVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip(
              label: 'Incidents',
              icon: Icons.priority_high,
              selected: layers.incidents,
              color: AppTheme.dangerRed,
              onTap: () =>
                  onChanged(layers.copyWith(incidents: !layers.incidents)),
            ),
            _Chip(
              label: 'Flood Risk',
              icon: Icons.flood,
              selected: layers.hazards,
              color: AppTheme.dangerRed,
              onTap: () =>
                  onChanged(layers.copyWith(hazards: !layers.hazards)),
            ),
            _Chip(
              label: 'Safe Paths',
              icon: Icons.route,
              selected: layers.safeRoute,
              color: AppTheme.safeGreen,
              onTap: () =>
                  onChanged(layers.copyWith(safeRoute: !layers.safeRoute)),
            ),
            _Chip(
              label: 'Shelters',
              icon: Icons.home_rounded,
              selected: layers.evacuationCenters,
              color: AppTheme.signalBlue,
              onTap: () => onChanged(
                layers.copyWith(evacuationCenters: !layers.evacuationCenters),
              ),
            ),
            _Chip(
              label: 'Teams',
              icon: Icons.shield_rounded,
              selected: layers.teams,
              color: const Color(0xFF7B1FA2),
              onTap: () =>
                  onChanged(layers.copyWith(teams: !layers.teams)),
            ),
            _Chip(
              label: 'Relay Points',
              icon: Icons.hub_rounded,
              selected: layers.loraNodes,
              color: AppTheme.deepNavy,
              onTap: () =>
                  onChanged(layers.copyWith(loraNodes: !layers.loraNodes)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : const Color(0xFFF3F7FE),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Locate FAB ─────────────────────────────────────────────────────────────

class _LocateFab extends StatelessWidget {
  const _LocateFab({
    required this.isLoading,
    required this.hasLocation,
    required this.isCenteredOnUser,
    required this.guidanceActive,
    required this.onPressed,
    required this.onToggleGuidance,
  });

  final bool isLoading;
  final bool hasLocation;
  // False once the map's been panned/zoomed away from the resident's own
  // position (see MapView.onCenteredChanged) - Google Maps dims this same
  // button in that state as a "tap to jump back" cue, instead of always
  // looking equally active regardless of where the camera's pointed.
  final bool isCenteredOnUser;
  final bool guidanceActive;
  final VoidCallback onPressed;
  final VoidCallback onToggleGuidance;

  @override
  Widget build(BuildContext context) {
    final isActive = hasLocation && isCenteredOnUser;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'locate_fab',
          onPressed: isLoading ? null : onPressed,
          backgroundColor: isActive ? AppTheme.safeGreen : Colors.white,
          elevation: 3,
          tooltip: !hasLocation
              ? 'Locate me'
              : isActive
                  ? 'Re-center'
                  : 'Jump back to my location',
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isActive ? Colors.white : AppTheme.signalBlue,
                  ),
                )
              : Icon(
                  hasLocation
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  size: 20,
                  color: isActive
                      ? Colors.white
                      : hasLocation
                          ? AppTheme.signalBlue
                          : AppTheme.textPrimary,
                ),
        ),
        if (hasLocation) ...[
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'guidance_fab',
            onPressed: onToggleGuidance,
            backgroundColor:
                guidanceActive ? AppTheme.dangerRed : AppTheme.signalBlue,
            elevation: 3,
            tooltip: guidanceActive ? 'Stop guidance' : 'Start guidance',
            child: Icon(
              guidanceActive
                  ? Icons.stop_rounded
                  : Icons.navigation_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Route summary card ────────────────────────────────────────────────────

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({
    required this.route,
    required this.centerName,
    required this.isCalculating,
    required this.onStartGuidance,
    required this.guidanceActive,
    required this.onClear,
  });

  final RouteModel route;
  final String centerName;
  final bool isCalculating;
  final VoidCallback onStartGuidance;
  final bool guidanceActive;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.navigation_rounded,
                  size: 16,
                  color: AppTheme.signalBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    centerName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.straighten_rounded,
                  label: '${route.distanceKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${route.estimatedMinutes} min',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.shield_rounded,
                  label: route.riskLevel,
                  color: route.riskLevel == 'LOW'
                      ? AppTheme.safeGreen
                      : route.riskLevel == 'HIGH'
                          ? AppTheme.dangerRed
                          : const Color(0xFFE8A317),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: FilledButton.icon(
                onPressed: isCalculating ? null : onStartGuidance,
                icon: Icon(
                  guidanceActive
                      ? Icons.stop_rounded
                      : Icons.navigation_rounded,
                  size: 15,
                ),
                label: Text(
                  guidanceActive ? 'Stop' : 'Start Guidance',
                  style: const TextStyle(fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: guidanceActive
                      ? AppTheme.dangerRed
                      : AppTheme.signalBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
      ],
    );
  }
}

// ── Weather badge ──────────────────────────────────────────────────────────

class _WeatherBadge extends StatelessWidget {
  const _WeatherBadge({
    required this.isDaytime,
    required this.rainfallMmPh,
  });

  final bool isDaytime;
  final double rainfallMmPh;

  @override
  Widget build(BuildContext context) {
    final icon = !isDaytime
        ? Icons.nightlight_round
        : rainfallMmPh > 10
        ? Icons.thunderstorm_rounded
        : rainfallMmPh > 0.5
        ? Icons.grain_rounded
        : Icons.wb_sunny_rounded;

    final label = !isDaytime
        ? 'Night'
        : rainfallMmPh > 10
        ? '${rainfallMmPh.toStringAsFixed(1)} mm/h'
        : rainfallMmPh > 0.5
        ? '${rainfallMmPh.toStringAsFixed(1)} mm/h'
        : 'Clear';

    final color = !isDaytime
        ? const Color(0xFF3B5998)
        : rainfallMmPh > 0.5
        ? AppTheme.signalBlue
        : AppTheme.safeGreen;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
