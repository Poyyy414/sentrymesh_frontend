import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/offline_map_download_button.dart';
import '../../data/models/evacuation_center_model.dart';
import '../../data/models/route_model.dart';
import '../../data/models/team_model.dart';
import 'state/asean_country.dart';
import 'widgets/evacuation_center_sheet.dart';
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
  MapLayerVisibility _layers = const MapLayerVisibility();
  double _rainfallMmPh = 0.0;
  bool _showLayerPanel = false;
  bool _guidanceActive = false;
  Timer? _guidanceTimer;

  List<EvacuationCenterModel> _evacuationCenters = [];
  List<TeamModel> _teamLocations = [];
  EvacuationCenterModel? _selectedCenter;
  RouteModel? _routeToCenter;
  bool _isCalculatingRoute = false;

  bool get _isDaytime {
    final h = DateTime.now().hour;
    return h >= 6 && h < 20;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchWeather();
    _fetchEvacuationCenters();
    _fetchTeamLocations();
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
    super.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Guidance started. Follow the highlighted safe path.'),
      ),
    );
    // Periodically re-center on user location
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshGuidanceLocation(),
    );
  }

  void _stopGuidance() {
    _guidanceTimer?.cancel();
    _guidanceTimer = null;
    setState(() => _guidanceActive = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guidance stopped')),
    );
  }

  Future<void> _refreshGuidanceLocation() async {
    if (!_guidanceActive || !mounted) return;
    try {
      final location = await _locationService.currentLocation();
      if (!mounted || !_guidanceActive) return;
      setState(() => _userLocation = location);

      // Recalculate route from current position if a center is selected
      if (_selectedCenter != null) {
        final deps = AppDependenciesScope.of(context);
        final route = await deps.mapRepository.fetchSafeRoute(
          origin: location,
          destination: _selectedCenter!.point,
        );
        if (mounted && _guidanceActive) {
          setState(() => _routeToCenter = route);
        }
      }
    } catch (_) {
      // Silently continue — guidance keeps running with last known location
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
      _autoSelectNearestCenter();
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
            child: MapView(
              country: _selectedCountry,
              userLocation: _userLocation,
              layers: _layers,
              route: _routeToCenter,
              isDaytime: _isDaytime,
              rainfallMmPh: _rainfallMmPh,
              evacuationCenters: _evacuationCenters,
              teamLocations: _teamLocations,
              selectedCenterId: _selectedCenter?.id,
              onEvacuationCenterTap: (center) {
                _showCenterSheet(center);
              },
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
              onCountryChanged: (c) => setState(() {
                _selectedCountry = c;
                _userLocation = null;
                _fetchWeather();
              }),
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

          // ── Route summary card ─────────────────────────────────────
          if (_routeToCenter != null && _selectedCenter != null)
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
    required this.guidanceActive,
    required this.onPressed,
    required this.onToggleGuidance,
  });

  final bool isLoading;
  final bool hasLocation;
  final bool guidanceActive;
  final VoidCallback onPressed;
  final VoidCallback onToggleGuidance;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'locate_fab',
          onPressed: isLoading ? null : onPressed,
          backgroundColor:
              hasLocation ? AppTheme.safeGreen : Colors.white,
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
                  color:
                      hasLocation ? Colors.white : AppTheme.textPrimary,
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
