import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/custom_button.dart';
import 'state/asean_country.dart';
import 'widgets/map_legend.dart';
import 'widgets/map_view.dart';
import 'widgets/route_summary_card.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 60,
              color: AppTheme.navy,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Evacuation Map',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  MapView(
                    country: _selectedCountry,
                    userLocation: _userLocation,
                    layers: _layers,
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 14,
                    child: Column(
                      children: [
                        _BlackoutMapStatus(userLocation: _userLocation),
                        const SizedBox(height: 10),
                        _CountrySelector(
                          selectedCountry: _selectedCountry,
                          onChanged: (country) {
                            setState(() {
                              _selectedCountry = country;
                              _userLocation = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 132,
                    left: 16,
                    right: 16,
                    child: _MapLayerControls(
                      layers: _layers,
                      onChanged: (layers) => setState(() => _layers = layers),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 78,
                    bottom: 16,
                    child: const MapLegend(),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _LocateButton(
                      isLoading: _isLocating,
                      onPressed: _locateUser,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  RouteSummaryCard(
                    countryName: _selectedCountry.name,
                    userLocation: _userLocation,
                  ),
                  const SizedBox(height: 12),
                  SentryButton(
                    label: _userLocation != null
                        ? 'Start Guidance'
                        : 'Locate Me First',
                    icon: _userLocation != null
                        ? Icons.navigation
                        : Icons.my_location,
                    onPressed: _userLocation != null
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Guidance started. Follow the highlighted safe path.',
                                ),
                              ),
                            );
                          }
                        : _locateUser,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _locateUser() async {
    if (_isLocating) {
      return;
    }

    setState(() => _isLocating = true);

    try {
      final location = await _locationService.currentLocation();
      if (!mounted) {
        return;
      }

      setState(() => _userLocation = location);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS locked. Evacuation route ready.')),
      );
    } on LocationServiceDisabledException {
      if (!mounted) {
        return;
      }
      _showLocationSettingsSnackBar();
    } on LocationPermissionPermanentlyDeniedException {
      if (!mounted) {
        return;
      }
      _showAppSettingsSnackBar();
    } on LocationPermissionDeniedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission was denied')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showLocationUnavailableSnackBar();
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showLocationSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Turn on device location to use live routing'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: _locationService.openLocationSettings,
        ),
      ),
    );
  }

  void _showAppSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Allow location access in app settings'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: _locationService.openAppSettings,
        ),
      ),
    );
  }

  void _showLocationUnavailableSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Location is not available yet. You can still view the selected country.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: _locationService.openLocationSettings,
        ),
      ),
    );
  }
}

class _BlackoutMapStatus extends StatelessWidget {
  const _BlackoutMapStatus({required this.userLocation});

  final GeoPoint? userLocation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.deepNavy.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.offline_bolt, color: AppTheme.safeGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                userLocation == null
                    ? 'Choose a country or tap locate to see nearby risk areas.'
                    : 'Your location is ready. Safer paths are highlighted.',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({
    required this.selectedCountry,
    required this.onChanged,
  });

  final AseanCountry selectedCountry;
  final ValueChanged<AseanCountry> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AseanCountry>(
      initialValue: selectedCountry,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.public, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppTheme.signalBlue),
        ),
      ),
      items: AseanCountry.countries.map((country) {
        return DropdownMenuItem(value: country, child: Text(country.name));
      }).toList(),
      onChanged: (country) {
        if (country != null) {
          onChanged(country);
        }
      },
    );
  }
}

class _MapLayerControls extends StatelessWidget {
  const _MapLayerControls({required this.layers, required this.onChanged});

  final MapLayerVisibility layers;
  final ValueChanged<MapLayerVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LayerToggle(
            label: 'Incidents',
            icon: Icons.priority_high,
            selected: layers.incidents,
            color: AppTheme.dangerRed,
            onTap: () =>
                onChanged(layers.copyWith(incidents: !layers.incidents)),
          ),
          _LayerToggle(
            label: 'Flood Risk',
            icon: Icons.flood,
            selected: layers.hazards,
            color: AppTheme.dangerRed,
            onTap: () => onChanged(layers.copyWith(hazards: !layers.hazards)),
          ),
          _LayerToggle(
            label: 'Safe Paths',
            icon: Icons.route,
            selected: layers.safeRoute,
            color: AppTheme.safeGreen,
            onTap: () =>
                onChanged(layers.copyWith(safeRoute: !layers.safeRoute)),
          ),
          _LayerToggle(
            label: 'Shelters',
            icon: Icons.home_rounded,
            selected: layers.evacuationCenters,
            color: AppTheme.signalBlue,
            onTap: () => onChanged(
              layers.copyWith(evacuationCenters: !layers.evacuationCenters),
            ),
          ),
          _LayerToggle(
            label: 'Relay Points',
            icon: Icons.hub,
            selected: layers.loraNodes,
            color: AppTheme.deepNavy,
            onTap: () =>
                onChanged(layers.copyWith(loraNodes: !layers.loraNodes)),
          ),
        ],
      ),
    );
  }
}

class _LayerToggle extends StatelessWidget {
  const _LayerToggle({
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(999),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 17, color: selected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        onPressed: isLoading ? null : onPressed,
        tooltip: 'Center on my location',
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location, color: AppTheme.textPrimary),
      ),
    );
  }
}
