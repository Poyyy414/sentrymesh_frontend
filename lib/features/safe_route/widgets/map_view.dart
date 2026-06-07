import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/config/map_tile_config.dart';
import '../../../core/services/location_service.dart';
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
    this.userLocation,
    super.key,
  });

  final AseanCountry country;
  final GeoPoint? userLocation;
  final MapLayerVisibility layers;

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

  double get _overlayScale {
    final zoom = _targetZoom;
    if (zoom >= 14) {
      return 0.01;
    }
    if (zoom >= 10) {
      return 0.03;
    }
    if (zoom >= 7) {
      return 0.18;
    }
    if (zoom >= 5) {
      return 0.55;
    }
    return 1.2;
  }

  LatLng _offset(LatLng origin, double latitude, double longitude) {
    final scale = _overlayScale;

    return LatLng(
      origin.latitude + latitude * scale,
      origin.longitude + longitude * scale,
    );
  }

  List<LatLng> _safeRoutePoints(LatLng origin) {
    return [
      _offset(origin, -0.8, -0.9),
      _offset(origin, -0.35, -0.35),
      origin,
      _offset(origin, 0.35, 0.45),
      _offset(origin, 0.85, 0.95),
    ];
  }

  List<LatLng> _evacuationCenters(LatLng origin) {
    return [
      _offset(origin, 0.85, 0.95),
      _offset(origin, -0.62, 0.72),
      _offset(origin, 0.58, -0.82),
    ];
  }

  List<LatLng> _incidentPoints(LatLng origin) {
    return [
      _offset(origin, 0.34, -0.48),
      _offset(origin, -0.42, 0.38),
      _offset(origin, 0.66, 0.62),
    ];
  }

  List<LatLng> _loraNodes(LatLng origin) {
    return [
      _offset(origin, -0.22, -0.55),
      _offset(origin, 0.18, 0.25),
      _offset(origin, 0.74, -0.08),
      _offset(origin, -0.66, 0.78),
    ];
  }

  List<Polygon> _hazardPolygons(LatLng origin) {
    return [
      Polygon(
        points: [
          _offset(origin, 1.35, -1.25),
          _offset(origin, 0.76, -0.55),
          _offset(origin, 0.62, 0.18),
          _offset(origin, 1.28, 0.52),
          _offset(origin, 1.72, -0.28),
        ],
        color: AppTheme.dangerRed.withValues(alpha: 0.24),
        borderColor: AppTheme.dangerRed.withValues(alpha: 0.68),
        borderStrokeWidth: 2,
      ),
      Polygon(
        points: [
          _offset(origin, -1.42, 0.18),
          _offset(origin, -0.86, 0.82),
          _offset(origin, -1.16, 1.48),
          _offset(origin, -1.88, 1.22),
          _offset(origin, -1.96, 0.42),
        ],
        color: AppTheme.warningAmber.withValues(alpha: 0.2),
        borderColor: AppTheme.warningAmber.withValues(alpha: 0.72),
        borderStrokeWidth: 2,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final userPoint = _userPoint;
    final origin = userPoint ?? _countryPoint;

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
        if (widget.layers.hazards) PolygonLayer(polygons: _hazardPolygons(origin)),
        if (widget.layers.safeRoute)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _safeRoutePoints(origin),
                strokeWidth: 7,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              Polyline(
                points: _safeRoutePoints(origin),
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
            if (widget.layers.evacuationCenters)
              for (final center in _evacuationCenters(origin))
                Marker(
                  point: center,
                  width: 38,
                  height: 38,
                  child: const _EvacuationCenterMarker(),
                ),
            if (widget.layers.incidents)
              for (final incident in _incidentPoints(origin))
                Marker(
                  point: incident,
                  width: 40,
                  height: 40,
                  child: const _IncidentMarker(),
                ),
            if (widget.layers.loraNodes)
              for (final node in _loraNodes(origin))
                Marker(
                  point: node,
                  width: 34,
                  height: 34,
                  child: const _LoRaNodeMarker(),
                ),
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
            TextSourceAttribution('OpenStreetMap contributors, CARTO'),
          ],
        ),
      ],
    );
  }
}

class _EvacuationCenterMarker extends StatelessWidget {
  const _EvacuationCenterMarker();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.signalBlue,
      shape: const CircleBorder(),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _IncidentMarker extends StatelessWidget {
  const _IncidentMarker();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.dangerRed,
      shape: const CircleBorder(),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.priority_high, color: Colors.white, size: 20),
      ),
    );
  }
}

class _LoRaNodeMarker extends StatelessWidget {
  const _LoRaNodeMarker();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.deepNavy,
      shape: const CircleBorder(),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.hub, color: Colors.white, size: 16),
      ),
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
