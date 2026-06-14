class AiModelInfo {
  const AiModelInfo({
    required this.featureColumns,
    this.timeWindow,
    this.threshold,
    this.metrics = const {},
    this.raw = const {},
  });

  final List<String> featureColumns;
  final int? timeWindow;
  final double? threshold;
  final Map<String, Object?> metrics;
  final Map<String, Object?> raw;

  factory AiModelInfo.fromJson(Map<String, Object?> json) {
    return AiModelInfo(
      featureColumns: _stringListFrom(
        json['feature_cols'] ?? json['featureColumns'] ?? json['features'],
      ),
      timeWindow: _intFrom(json['time_window'] ?? json['timeWindow']),
      threshold: _doubleFrom(json['threshold']),
      metrics: _mapFrom(json['metrics']),
      raw: json,
    );
  }
}

class PredictionResponseModel {
  const PredictionResponseModel({required this.nodes, this.raw = const {}});

  final List<NodePredictionModel> nodes;
  final Map<String, Object?> raw;

  factory PredictionResponseModel.fromJson(Map<String, Object?> json) {
    final items = _listFrom(
      json['predictions'] ?? json['results'] ?? json['nodes'] ?? json['items'],
    );

    final nodes = items.isEmpty
        ? [NodePredictionModel.fromJson(json)]
        : items
              .map(_mapFrom)
              .where((item) => item.isNotEmpty)
              .map(NodePredictionModel.fromJson)
              .toList();

    return PredictionResponseModel(
      nodes: nodes.where((node) => node.raw.isNotEmpty).toList(),
      raw: json,
    );
  }

  NodePredictionModel? get firstNode {
    if (nodes.isEmpty) {
      return null;
    }

    return nodes.first;
  }
}

class NodePredictionModel {
  const NodePredictionModel({
    required this.nodeId,
    required this.severity,
    required this.eventProbability,
    required this.alert,
    required this.alertLevel,
    this.raw = const {},
  });

  final String nodeId;
  final double? severity;
  final double? eventProbability;
  final bool alert;
  final String alertLevel;
  final Map<String, Object?> raw;

  factory NodePredictionModel.fromJson(Map<String, Object?> json) {
    final nested = _mapFrom(
      json['prediction_payload'] ??
          json['predictionPayload'] ??
          json['prediction'] ??
          json['result'],
    );
    final source = {...nested, ...json};

    final eventProbability = _doubleFrom(
      source['event_prob'] ??
          source['eventProbability'] ??
          source['probability'] ??
          source['confidence'],
    );

    final alertLevel =
        source['alert_level'] ??
        source['alertLevel'] ??
        source['risk_level'] ??
        source['riskLevel'];

    return NodePredictionModel(
      nodeId:
          source['node_id']?.toString() ??
          source['nodeId']?.toString() ??
          source['id']?.toString() ??
          source['hazard_type']?.toString() ??
          '',
      severity: _doubleFrom(source['severity'] ?? source['score']),
      eventProbability: eventProbability,
      alert:
          _boolFrom(source['alert']) ??
          _isAlertLevel(alertLevel?.toString()) ??
          (eventProbability ?? 0) >= 0.5,
      alertLevel: _titleCase(alertLevel?.toString() ?? 'watch'),
      raw: source,
    );
  }

  String get probabilityLabel {
    if (eventProbability == null) {
      return 'Awaiting score';
    }

    final value = eventProbability! <= 1
        ? eventProbability! * 100
        : eventProbability!;
    return '${value.clamp(0, 100).round()}% likelihood';
  }

  String get severityLabel {
    if (severity == null) {
      return alert ? '$alertLevel alert' : 'Monitor conditions';
    }

    return 'Severity ${severity!.toStringAsFixed(1)}';
  }
}

List<Object?> _listFrom(Object? value) {
  if (value is List) {
    return value;
  }

  return const [];
}

List<String> _stringListFrom(Object? value) {
  return _listFrom(value).map((item) => item.toString()).toList();
}

Map<String, Object?> _mapFrom(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return const {};
}

double? _doubleFrom(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

int? _intFrom(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

bool? _boolFrom(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
  }

  if (value is num) {
    return value != 0;
  }

  return null;
}

bool? _isAlertLevel(String? value) {
  final normalized = value?.toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  if (normalized.contains('high') || normalized.contains('critical')) {
    return true;
  }
  if (normalized.contains('low') || normalized.contains('safe')) {
    return false;
  }

  return null;
}

String _titleCase(String value) {
  final normalized = value
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim()
      .toLowerCase();
  if (normalized.isEmpty) {
    return value;
  }

  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
