import 'package:flutter_test/flutter_test.dart';
import 'package:sentrymesh_frontend/data/models/weather_snapshot_model.dart';

void main() {
  test('parses OpenWeather rain and temperature fields', () {
    final weather = WeatherSnapshotModel.fromJson({
      'provider': 'OpenWeather',
      'weather': {
        'main': {'temp': 26.7, 'pressure': 1008},
        'rain': {'1h': 4.2},
      },
    });

    expect(weather.providerLabel, 'OpenWeather');
    expect(weather.rainfallMmPerHour, 4.2);
    expect(weather.temperatureC, 26.7);
    expect(weather.pressureHpa, 1008);
  });

  test('parses Open-Meteo current precipitation fields', () {
    final weather = WeatherSnapshotModel.fromJson({
      'source': 'Open-Meteo',
      'current': {
        'precipitation': '2.5',
        'temperature_2m': '27.1',
        'pressure_msl': '1009.4',
      },
    });

    expect(weather.providerLabel, 'Open-Meteo');
    expect(weather.rainfallMmPerHour, 2.5);
    expect(weather.temperatureC, 27.1);
    expect(weather.pressureHpa, 1009.4);
  });
}
