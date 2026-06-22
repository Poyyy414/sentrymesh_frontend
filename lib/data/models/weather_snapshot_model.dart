class WeatherSnapshotModel {
  const WeatherSnapshotModel({
    required this.rainfallMmPerHour,
    required this.temperatureC,
    required this.pressureHpa,
    this.providerLabel = 'Live weather',
    this.raw = const {},
  });

  final double rainfallMmPerHour;
  final double temperatureC;
  final double pressureHpa;
  final String providerLabel;
  final Map<String, Object?> raw;

  factory WeatherSnapshotModel.fromJson(Map<String, Object?> json) {
    final weather = _mapFrom(json['weather']);
    final current = _mapFrom(
      json['current'] ?? weather['current'] ?? json['current_weather'],
    );
    final currentWeather = _mapFrom(
      json['current_weather'] ?? weather['current_weather'],
    );
    final main = _mapFrom(weather['main'] ?? json['main']);
    final rainMap = _mapFrom(
      weather['rain'] ?? current['rain'] ?? json['rain'],
    );

    return WeatherSnapshotModel(
      rainfallMmPerHour: _rainfallFrom(
        json,
        weather,
        current,
        currentWeather,
        rainMap,
      ),
      temperatureC:
          _firstDouble([
            json['temperature_c'],
            json['temperatureC'],
            json['temperature'],
            weather['temperature_c'],
            weather['temperature'],
            main['temp'],
            current['temperature_2m'],
            current['temperature'],
            current['temp'],
            currentWeather['temperature'],
          ]) ??
          27,
      pressureHpa:
          _firstDouble([
            json['pressure_hpa'],
            json['pressure'],
            weather['pressure'],
            main['pressure'],
            current['pressure_msl'],
            current['surface_pressure'],
          ]) ??
          1013,
      providerLabel: _providerLabel(json),
      raw: json,
    );
  }

  static double _rainfallFrom(
    Map<String, Object?> json,
    Map<String, Object?> weather,
    Map<String, Object?> current,
    Map<String, Object?> currentWeather,
    Map<String, Object?> rainMap,
  ) {
    final direct =
        _firstDouble([
          json['rainfall_mm_per_hour'],
          json['rainfallMmPerHour'],
          json['rainfall_mm_ph'],
          json['rainfall_mm'],
          json['precipitation'],
          weather['rainfall_mm'],
          weather['precipitation'],
          current['precipitation'],
          current['rain'],
          currentWeather['precipitation'],
          currentWeather['rain'],
          rainMap['1h'],
        ]) ??
        0;

    if (direct > 0) {
      return direct;
    }

    final threeHourRain = _asDouble(rainMap['3h']);
    if (threeHourRain != null) {
      return threeHourRain / 3;
    }

    return direct;
  }

  static String _providerLabel(Map<String, Object?> json) {
    final provider =
        json['provider'] ??
        json['source'] ??
        _mapFrom(json['weather'])['provider'] ??
        _mapFrom(json['weather'])['source'];
    final value = provider?.toString().trim();
    if (value == null || value.isEmpty) {
      return 'Live weather';
    }
    return value;
  }
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

double? _firstDouble(List<Object?> values) {
  for (final value in values) {
    final parsed = _asDouble(value);
    if (parsed != null) return parsed;
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}
