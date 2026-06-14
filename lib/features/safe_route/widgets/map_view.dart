import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/config/map_tile_config.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/route_model.dart';
import '../state/asean_country.dart';

class MapLayerVisibility {
  const MapLayerVisibility({
    this.incidents = true,
    this.hazards = true,
    this.safeRoute = true,
    this.evacuationCenters = true,
    this.loraNodes = true,
    this.location = true,
  });

  final bool incidents;
  final bool hazards;
  final bool safeRoute;
  final bool evacuationCenters;
  final bool loraNodes;
  final bool location;

  MapLayerVisibility copyWith({
    bool? incidents,
    bool? hazards,
    bool? safeRoute,
    bool? evacuationCenters,
    bool? loraNodes,
    bool? location,
  }) {
    return MapLayerVisibility(
      incidents: incidents ?? this.incidents,
      hazards: hazards ?? this.hazards,
      safeRoute: safeRoute ?? this.safeRoute,
      evacuationCenters: evacuationCenters ?? this.evacuationCenters,
      loraNodes: loraNodes ?? this.loraNodes,
      location: location ?? this.location,
    );
  }
}

class MapView extends StatefulWidget {
  const MapView({
    required this.country,
    required this.layers,
    this.route,
    this.userLocation,
    super.key,
  });

  final AseanCountry country;
  final GeoPoint? userLocation;
  final MapLayerVisibility layers;
  final RouteModel? route;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final _mapController = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cameraTargetChanged(oldWidget)) {
      _syncCamera();
    }
  }

  bool _cameraTargetChanged(MapView oldWidget) {
    final oldLocation = oldWidget.userLocation;
    final newLocation = widget.userLocation;

    return oldWidget.country.code != widget.country.code ||
        oldLocation?.latitude != newLocation?.latitude ||
        oldLocation?.longitude != newLocation?.longitude;
  }

  void _onMapReady() {
    _mapReady = true;
    _syncCamera();
  }

  void _syncCamera() {
    if (!_mapReady) {
      return;
    }

    _mapController.move(_targetPoint, _targetZoom);
  }

  LatLng get _targetPoint {
    final location = widget.userLocation;

    return LatLng(
      location?.latitude ?? widget.country.latitude,
      location?.longitude ?? widget.country.longitude,
    );
  }

  double get _targetZoom {
    return widget.userLocation == null ? widget.country.zoom : 15;
  }

  LatLng get _countryPoint {
    return LatLng(widget.country.latitude, widget.country.longitude);
  }

  LatLng? get _userPoint {
    final location = widget.userLocation;
    if (location == null) {
      return null;
    }

    return LatLng(location.latitude, location.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = _userPoint;
    final routePoints =
        widget.route?.waypoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList() ??
        const <LatLng>[];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _targetPoint,
        initialZoom: _targetZoom,
        minZoom: 3,
        maxZoom: 18,
        backgroundColor: const Color(0xFFE6ECF2),
        keepAlive: true,
        onMapReady: _onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: MapTileConfig.mapboxStreetsUrl,
          userAgentPackageName: 'com.example.sentrymesh_frontend',
          maxZoom: 18,
        ),
        if (widget.layers.safeRoute && routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 7,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              Polyline(
                points: routePoints,
                strokeWidth: 4,
                color: AppTheme.safeGreen,
              ),
            ],
          ),
        if (widget.layers.location && userPoint != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: userPoint,
                radius: 120,
                useRadiusInMeter: true,
                color: AppTheme.signalBlue.withValues(alpha: 0.18),
                borderColor: AppTheme.signalBlue.withValues(alpha: 0.45),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.layers.location)
              if (userPoint != null)
                Marker(
                  point: userPoint,
                  width: 44,
                  height: 44,
                  child: const _UserLocationMarker(),
                )
              else
                Marker(
                  point: _countryPoint,
                  width: 42,
                  height: 42,
                  child: _CountryCenterMarker(countryCode: widget.country.code),
                ),
          ],
        ),
        const RichAttributionWidget(
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution('Mapbox, OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.signalBlue.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.signalBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.signalBlue.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const SizedBox(width: 24, height: 24),
        ),
      ),
    );
  }
}

class _CountryCenterMarker extends StatelessWidget {
  const _CountryCenterMarker({required this.countryCode});

  final String countryCode;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: Center(
        child: Text(
          countryCode,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
