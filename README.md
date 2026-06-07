# SentryMesh Frontend

Flutter mobile frontend for Project SentryMesh, a disaster-resilience app that supports alerts, SOS rescue requests, safe routes, family safety checks, and offline-first LoRaWAN fallback.

## Folder Structure

```txt
lib/
|-- app/                  # App shell, routes, theme, constants
|-- core/                 # Config, DI, network, services, utils, shared widgets
|   |-- di/               # Dependency container
|   |-- services/lora/    # LoRaWAN distress-ping abstraction
|   `-- services/offline/ # Offline map/cache support
|-- data/                 # Models, repositories, local/remote data sources
|-- features/             # Feature-first UI modules
`-- shared/               # Enums and cross-feature primitives
```

Mocks and test-only fixtures live under `test/fixtures/` so sample data does not become production app data.

## State Management

The current scaffold keeps each feature's future state in a `state/` folder without adding a package yet. Once the team chooses a package, use one pattern consistently:

- Riverpod: rename state files into providers/notifiers.
- GetX: keep controllers under each feature.
- BLoC: split into bloc/event/state files.

## Backend

FastAPI calls are isolated behind `core/network`, `data/sources/remote`, and `data/repositories`. Set the backend URL with:

```sh
flutter run --dart-define=SENTRYMESH_API_BASE_URL=http://your-fastapi-host:8000
```

## Mock Auth

Until the FastAPI auth backend is ready, the Flutter app uses frontend-only mock login/register.

Seeded accounts:

- User: `user123@gmail.com` / `12345678`
- Responder: `responder123@gmail.com` / `12345678`

The user account opens the resident mobile app. The responder account opens the responder app with dashboard, incident queue, live map, teams, and reports.

Registration currently requires:

- `first_name`
- `last_name`
- `email`
- `address`
- `password`

## Maps

The Safe Route Map uses `flutter_map` with token-free CARTO/OpenStreetMap raster tiles, so the frontend does not need a Mapbox token. Run the app normally:

```sh
flutter run
```

The Safe Route Map should receive route and hazard geometry from FastAPI, then render it in Flutter as:

- green safe-route line
- red flooded-area polygons
- blue current-location marker
- evacuation-center markers

The map includes an ASEAN country selector. It recenters the map to the selected ASEAN country, but it does not calculate navigation by itself. FastAPI still needs to return country-specific evacuation centers, hazard polygons, blocked roads, and route geometry.

The locate button requests foreground location permission and centers the map on the user's current GPS location. On Android this uses `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`; on iOS this uses `NSLocationWhenInUseUsageDescription`.

For SentryMesh's disaster/offline scenario, add a local tile cache or packaged offline tile provider for target barangays before an emergency.
