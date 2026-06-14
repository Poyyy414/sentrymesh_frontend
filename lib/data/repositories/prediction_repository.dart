import '../models/prediction_model.dart';
import '../sources/remote/prediction_api.dart';

class PredictionBundle {
  const PredictionBundle({
    required this.modelInfo,
    required this.flood,
    required this.landslide,
    required this.fetchedAt,
  });

  final AiModelInfo modelInfo;
  final NodePredictionModel? flood;
  final NodePredictionModel? landslide;
  final DateTime fetchedAt;
}

class PredictionRepository {
  const PredictionRepository({required PredictionApi remote})
    : _remote = remote;

  final PredictionApi _remote;

  Future<PredictionBundle> fetchHomePredictions() async {
    final modelInfo = await _remote.fetchModelInfo();
    final featureColumns = modelInfo.featureColumns.isEmpty
        ? _fallbackFeatureColumns
        : modelInfo.featureColumns;

    final response = await _remote.predictNodes(
      nodes: [
        _nodePayload(
          nodeId: 42,
          featureColumns: featureColumns,
          signals: _nagaFloodSignals,
        ),
        _nodePayload(
          nodeId: 73,
          featureColumns: featureColumns,
          signals: _nagaLandslideSignals,
        ),
      ],
    );

    final flood = _nodeById(response.nodes, '42') ?? response.firstNode;
    final landslide =
        _nodeById(response.nodes, '73') ??
        (response.nodes.length > 1 ? response.nodes[1] : null);

    return PredictionBundle(
      modelInfo: modelInfo,
      flood: flood,
      landslide: landslide,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, Object?> _nodePayload({
    required int nodeId,
    required List<String> featureColumns,
    required Map<String, num> signals,
  }) {
    return {
      'node_id': nodeId,
      'features': [
        for (var index = 0; index < featureColumns.length; index++)
          _featureValueFor(featureColumns[index], index, signals),
      ],
    };
  }

  double _featureValueFor(
    String featureName,
    int index,
    Map<String, num> signals,
  ) {
    final normalized = _normalize(featureName);

    for (final entry in signals.entries) {
      if (_normalize(entry.key) == normalized) {
        return entry.value.toDouble();
      }
    }

    for (final alias in _featureAliases.entries) {
      if (alias.value.any((item) => normalized.contains(item))) {
        return signals[alias.key]?.toDouble() ?? _fallbackValue(index);
      }
    }

    return _fallbackValue(index);
  }

  double _fallbackValue(int index) {
    if (index < _fallbackFeatures.length) {
      return _fallbackFeatures[index].toDouble();
    }

    return 0;
  }

  NodePredictionModel? _nodeById(
    List<NodePredictionModel> nodes,
    String nodeId,
  ) {
    for (final node in nodes) {
      if (node.nodeId == nodeId) {
        return node;
      }
    }

    return null;
  }
}

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

const _fallbackFeatureColumns = [
  'latitude',
  'longitude',
  'hour',
  'rainfall_mm',
  'wind_speed_kph',
  'hazard_type',
  'water_level_m',
  'river_level_m',
  'slope',
  'soil_moisture',
  'surface_runoff',
  'upstream_water_level',
  'ground_movement',
  'humidity',
  'pressure',
  'temperature',
  'elevation',
  'distance_to_river',
  'recent_reports',
];

const _fallbackFeatures = [
  14.5,
  121.0,
  6,
  162,
  14,
  1,
  8.2,
  7.3,
  0.3,
  0.6,
  0.4,
  0.2,
  0.05,
  65,
  985,
  18,
  120,
  20,
  4,
];

const _featureAliases = {
  'latitude': ['latitude', 'lat'],
  'longitude': ['longitude', 'lng', 'lon'],
  'hour': ['hour', 'time'],
  'rainfall_mm': ['rainfall', 'rain', 'precipitation'],
  'wind_speed_kph': ['wind'],
  'hazard_type': ['hazard', 'type'],
  'water_level_m': ['waterlevel', 'flooddepth', 'waterheight'],
  'river_level_m': ['riverlevel', 'streamlevel'],
  'slope': ['slope'],
  'soil_moisture': ['soilmoisture', 'soil', 'saturation'],
  'surface_runoff': ['runoff'],
  'upstream_water_level': ['upstream'],
  'ground_movement': ['groundmovement', 'movement'],
  'humidity': ['humidity'],
  'pressure': ['pressure'],
  'temperature': ['temperature', 'temp'],
  'elevation': ['elevation', 'altitude'],
  'distance_to_river': ['distancetoriver', 'riverdistance'],
  'recent_reports': ['report', 'pulse', 'community'],
};

const _nagaFloodSignals = {
  'latitude': 13.6218,
  'longitude': 123.1948,
  'hour': 9,
  'rainfall_mm': 162,
  'wind_speed_kph': 42,
  'hazard_type': 1,
  'water_level_m': 1.42,
  'river_level_m': 1.68,
  'slope': 0.18,
  'soil_moisture': 0.74,
  'surface_runoff': 0.58,
  'upstream_water_level': 1.91,
  'ground_movement': 0.03,
  'humidity': 88,
  'pressure': 988,
  'temperature': 27,
  'elevation': 21,
  'distance_to_river': 0.7,
  'recent_reports': 6,
};

const _nagaLandslideSignals = {
  'latitude': 13.6502,
  'longitude': 123.2477,
  'hour': 9,
  'rainfall_mm': 118,
  'wind_speed_kph': 38,
  'hazard_type': 2,
  'water_level_m': 0.34,
  'river_level_m': 0.52,
  'slope': 31,
  'soil_moisture': 0.86,
  'surface_runoff': 0.44,
  'upstream_water_level': 0.61,
  'ground_movement': 0.21,
  'humidity': 91,
  'pressure': 986,
  'temperature': 26,
  'elevation': 126,
  'distance_to_river': 2.4,
  'recent_reports': 4,
};
