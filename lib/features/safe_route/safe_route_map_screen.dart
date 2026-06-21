import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/location_service.dart';
import '../../data/models/evacuation_center_model.dart';
import '../../data/models/rescue_request_model.dart';
import '../../data/models/route_model.dart';
import '../../shared/enums/rescue_status.dart';
import 'state/asean_country.dart';
import 'widgets/map_view.dart';

class SafeRouteMapScreen extends StatefulWidget {
  const SafeRouteMapScreen({super.key});

  @override
  State<SafeRouteMapScreen> createState() => _SafeRouteMapScreenState();
}

class _SafeRouteMapScreenState extends State<SafeRouteMapScreen> {
  final _locationService = const LocationService();

  AseanCountry _selectedCountry = AseanCountry.defaultCountry;
  GeoPoint? _userLocation;
  bool _isLocating = false;
  bool _isLoadingMapData = false;
  MapLayerVisibility _layers = const MapLayerVisibility();
  double _rainfallMmPh = 0.0;
  bool _showLayerPanel = false;
  List<EvacuationCenterModel> _evacuationCenters = const [];
  List<RescueRequestModel> _incidents = const [];
  List<SeverityHeatPoint> _heatPoints = const [];
  EvacuationCenterModel? _selectedEvacuationCenter;
  RouteModel? _evacuationRoute;
  String? _mapStatus;

  bool get _isDaytime {
    final h = DateTime.now().hour;
    return h >= 6 && h < 20;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMapData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchWeather();
  }

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

  Future<void> _locateUser() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final location = await _locationService.currentLocation();
      if (!mounted) return;
      setState(() => _userLocation = location);
      _fetchWeather();
      await _loadMapData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS locked. Evacuation route ready.')),
      );
    } on LocationServiceDisabledException {
      if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission was denied')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Location unavailable. You can still view the map.',
          ),
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

  Future<void> _loadMapData() async {
    if (_isLoadingMapData) return;

    setState(() {
      _isLoadingMapData = true;
      _mapStatus = null;
    });

    try {
      final deps = AppDependenciesScope.of(context);
      final results = await Future.wait<dynamic>([
        deps.rescueRepository.fetchEvacuationCenters(),
        deps.rescueRepository.fetchRequests(),
      ]);
      if (!mounted) return;

      final centers = results[0] as List<EvacuationCenterModel>;
      final requests = (results[1] as List<RescueRequestModel>)
          .where(
            (request) =>
                request.latitude != null &&
                request.longitude != null &&
                request.status != RescueStatus.resolved &&
                request.status != RescueStatus.cancelled,
          )
          .toList();
      final origin = GeoPoint(
        latitude: _userLocation?.latitude ?? _selectedCountry.latitude,
        longitude: _userLocation?.longitude ?? _selectedCountry.longitude,
      );
      final selectedCenter = _nearestOpenCenter(origin, centers);
      final route = selectedCenter == null
          ? null
          : await deps.mapRepository.fetchSafeRoute(
              origin: origin,
              destination: GeoPoint(
                latitude: selectedCenter.latitude,
                longitude: selectedCenter.longitude,
              ),
            );

      if (!mounted) return;
      setState(() {
        _evacuationCenters = centers;
        _incidents = requests;
        _heatPoints = _heatPointsFor(requests);
        _selectedEvacuationCenter = selectedCenter;
        _evacuationRoute = route;
        _mapStatus = selectedCenter == null
            ? 'No open evacuation center found.'
            : route == null
            ? 'Shelters loaded. Route service unavailable.'
            : 'Safest route to ${selectedCenter.name} ready.';
        _isLoadingMapData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mapStatus = 'Map layers unavailable. Pull data again later.';
        _isLoadingMapData = false;
      });
    }
  }

  EvacuationCenterModel? _nearestOpenCenter(
    GeoPoint origin,
    List<EvacuationCenterModel> centers,
  ) {
    final openCenters = centers
        .where((center) => center.isOpen && center.availableSlots > 0)
        .toList();
    final candidates = openCenters.isEmpty ? centers : openCenters;
    if (candidates.isEmpty) return null;

    candidates.sort(
      (a, b) => _distanceScore(origin, a).compareTo(_distanceScore(origin, b)),
    );
    return candidates.first;
  }

  double _distanceScore(GeoPoint origin, EvacuationCenterModel center) {
    final dLat = origin.latitude - center.latitude;
    final dLon = origin.longitude - center.longitude;
    return dLat * dLat + dLon * dLon;
  }

  List<SeverityHeatPoint> _heatPointsFor(List<RescueRequestModel> requests) {
    if (requests.isEmpty) {
      return [
        SeverityHeatPoint(
          location: GeoPoint(
            latitude: _selectedCountry.latitude + 0.012,
            longitude: _selectedCountry.longitude - 0.009,
          ),
          label: 'Lowest observed severity',
          severity: 0.18,
        ),
        SeverityHeatPoint(
          location: GeoPoint(
            latitude: _selectedCountry.latitude - 0.01,
            longitude: _selectedCountry.longitude + 0.011,
          ),
          label: 'Highest projected severity',
          severity: 0.82,
        ),
      ];
    }

    return requests
        .map(
          (request) => SeverityHeatPoint(
            location: GeoPoint(
              latitude: request.latitude!,
              longitude: request.longitude!,
            ),
            label: request.locationLabel ?? request.description,
            severity: request.peopleNeedingHelp >= 5
                ? 0.9
                : request.peopleNeedingHelp >= 2
                ? 0.55
                : 0.24,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────
          Positioned.fill(
            child: MapView(
              country: _selectedCountry,
              userLocation: _userLocation,
              layers: _layers,
              route: _evacuationRoute,
              evacuationCenters: _evacuationCenters,
              incidents: _incidents,
              heatPoints: _heatPoints,
              isDaytime: _isDaytime,
              rainfallMmPh: _rainfallMmPh,
            ),
          ),

          // ── Top bar: compact overlay ─────────────────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: _TopBar(
              selectedCountry: _selectedCountry,
              isDaytime: _isDaytime,
              rainfallMmPh: _rainfallMmPh,
              showLayers: _showLayerPanel,
              onToggleLayers: () =>
                  setState(() => _showLayerPanel = !_showLayerPanel),
              onCountryChanged: (c) {
                setState(() {
                  _selectedCountry = c;
                  _userLocation = null;
                  _evacuationRoute = null;
                  _selectedEvacuationCenter = null;
                });
                _fetchWeather();
                _loadMapData();
              },
            ),
          ),

          // ── Layer toggle panel ───────────────────────────────────────
          if (_showLayerPanel)
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
              onPressed: _locateUser,
            ),
          ),

          // ── Weather badge (bottom-left) ──────────────────────────────
          Positioned(
            left: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: _WeatherBadge(
              isDaytime: _isDaytime,
              rainfallMmPh: _rainfallMmPh,
            ),
          ),

          Positioned(
            left: 14,
            right: 84,
            bottom: MediaQuery.paddingOf(context).bottom + 70,
            child: _EvacuationRouteBadge(
              isLoading: _isLoadingMapData,
              center: _selectedEvacuationCenter,
              route: _evacuationRoute,
              status: _mapStatus,
              onRefresh: _loadMapData,
            ),
          ),
        ],
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
  });

  final AseanCountry selectedCountry;
  final bool isDaytime;
  final double rainfallMmPh;
  final bool showLayers;
  final VoidCallback onToggleLayers;
  final ValueChanged<AseanCountry> onCountryChanged;

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
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (c) {
                if (c != null) onCountryChanged(c);
              },
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
              label: 'Flood Risk',
              icon: Icons.flood,
              selected: layers.hazards,
              color: AppTheme.dangerRed,
              onTap: () => onChanged(layers.copyWith(hazards: !layers.hazards)),
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
              Icon(icon, size: 15, color: selected ? Colors.white : color),
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
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasLocation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'locate_fab',
          onPressed: isLoading ? null : onPressed,
          backgroundColor: hasLocation ? AppTheme.safeGreen : Colors.white,
          elevation: 3,
          tooltip: hasLocation ? 'Re-center' : 'Locate me',
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: hasLocation ? Colors.white : AppTheme.signalBlue,
                  ),
                )
              : Icon(
                  hasLocation
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  size: 20,
                  color: hasLocation ? Colors.white : AppTheme.textPrimary,
                ),
        ),
        if (hasLocation) ...[
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'guidance_fab',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Guidance started. Follow the highlighted safe path.',
                  ),
                ),
              );
            },
            backgroundColor: AppTheme.signalBlue,
            elevation: 3,
            tooltip: 'Start guidance',
            child: const Icon(
              Icons.navigation_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Weather badge ──────────────────────────────────────────────────────────

class _EvacuationRouteBadge extends StatelessWidget {
  const _EvacuationRouteBadge({
    required this.isLoading,
    required this.center,
    required this.route,
    required this.status,
    required this.onRefresh,
  });

  final bool isLoading;
  final EvacuationCenterModel? center;
  final RouteModel? route;
  final String? status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final center = this.center;
    final route = this.route;
    final title = center == null ? 'Evacuation route' : 'To ${center.name}';
    final subtitle = isLoading
        ? 'Loading shelters and safest path...'
        : route != null
        ? '${route.distanceKm.toStringAsFixed(1)} km - ${route.estimatedMinutes} min - ${route.riskLevel} risk'
        : status ?? 'Tap refresh to load route.';
    final color = route != null ? AppTheme.safeGreen : AppTheme.signalBlue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                route != null ? Icons.route_rounded : Icons.home_rounded,
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: 'Refresh map data',
                visualDensity: VisualDensity.compact,
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeatherBadge extends StatelessWidget {
  const _WeatherBadge({required this.isDaytime, required this.rainfallMmPh});

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
