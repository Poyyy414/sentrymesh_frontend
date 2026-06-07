class MapTileConfig {
  const MapTileConfig._();

  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue:
        'pk.eyJ1IjoiYW1wb3kiLCJhIjoiY21weTJqNGIwMDFyeTJycXl4bjVsMDVpaSJ9.EP-crdJD41BmjI5uhdamJw',
  );

  static String get mapboxStreetsUrl {
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';
  }

  static String get mapboxSatelliteStreetsUrl {
    return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';
  }
}
