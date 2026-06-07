class AseanCountry {
  const AseanCountry({
    required this.code,
    required this.name,
    required this.longitude,
    required this.latitude,
    required this.zoom,
  });

  final String code;
  final String name;
  final double longitude;
  final double latitude;
  final double zoom;

  static const countries = [
    AseanCountry(
      code: 'BN',
      name: 'Brunei',
      longitude: 114.7277,
      latitude: 4.5353,
      zoom: 7.2,
    ),
    AseanCountry(
      code: 'KH',
      name: 'Cambodia',
      longitude: 104.9910,
      latitude: 12.5657,
      zoom: 6.0,
    ),
    AseanCountry(
      code: 'ID',
      name: 'Indonesia',
      longitude: 117.2800,
      latitude: -2.5489,
      zoom: 4.2,
    ),
    AseanCountry(
      code: 'LA',
      name: 'Laos',
      longitude: 102.4955,
      latitude: 19.8563,
      zoom: 5.8,
    ),
    AseanCountry(
      code: 'MY',
      name: 'Malaysia',
      longitude: 101.9758,
      latitude: 4.2105,
      zoom: 5.2,
    ),
    AseanCountry(
      code: 'MM',
      name: 'Myanmar',
      longitude: 95.9560,
      latitude: 21.9162,
      zoom: 5.2,
    ),
    AseanCountry(
      code: 'PH',
      name: 'Philippines',
      longitude: 123.1948,
      latitude: 13.6218,
      zoom: 7.0,
    ),
    AseanCountry(
      code: 'SG',
      name: 'Singapore',
      longitude: 103.8198,
      latitude: 1.3521,
      zoom: 10.5,
    ),
    AseanCountry(
      code: 'TH',
      name: 'Thailand',
      longitude: 100.9925,
      latitude: 15.8700,
      zoom: 5.5,
    ),
    AseanCountry(
      code: 'VN',
      name: 'Vietnam',
      longitude: 108.2772,
      latitude: 14.0583,
      zoom: 5.5,
    ),
  ];

  static AseanCountry get defaultCountry {
    return countries.firstWhere((country) => country.code == 'PH');
  }
}
