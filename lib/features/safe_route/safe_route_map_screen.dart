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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: SafeArea(
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
                    onPressed: () {},
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Safe Route Map',
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
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 14,
                    child: _MapControls(
                      selectedCountry: _selectedCountry,
                      onCountryChanged: (country) {
                        setState(() {
                          _selectedCountry = country;
                          _userLocation = null;
                        });
                      },
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
                    label: 'Start Navigation',
                    icon: Icons.navigation,
                    onPressed: null,
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
        const SnackBar(content: Text('Current location found')),
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
        content: const Text('Turn on device location to use this feature'),
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
        content: const Text('No GPS fix yet. Try turning location on outdoors.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: _locationService.openLocationSettings,
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.selectedCountry,
    required this.onCountryChanged,
  });

  final AseanCountry selectedCountry;
  final ValueChanged<AseanCountry> onCountryChanged;

  @override
  Widget build(BuildContext context) {
    return _CountrySelector(
      selectedCountry: selectedCountry,
      onChanged: onCountryChanged,
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
      value: selectedCountry,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.public, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
        return DropdownMenuItem(
          value: country,
          child: Text(country.name),
        );
      }).toList(),
      onChanged: (country) {
        if (country != null) {
          onChanged(country);
        }
      },
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({
    required this.isLoading,
    required this.onPressed,
  });

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
