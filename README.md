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

Backend calls are isolated behind `core/network`, `data/sources/remote`, and `data/repositories`. By default, the frontend uses the deployed NestJS app backend:

```sh
https://backend-mesh-t9rc.onrender.com
```

Run the app normally to use it:

```sh
flutter run
```

Override the backend URL for local development with:

```sh
flutter run --dart-define=SENTRYMESH_API_BASE_URL=http://your-nestjs-host:3000
```

AI hazard prediction uses the FastAPI model service separately:

```sh
https://apexnode-ai.onrender.com
```

Override it with:

```sh
flutter run --dart-define=SENTRYMESH_AI_BASE_URL=http://your-fastapi-ai-host:8000
```

The prediction flow calls `GET /model/info` first to read `feature_cols`, then sends ordered node features to `POST /predict`. The model response is shown in the Home screen's AI Flood Forecast card.

Registration posts to `POST /api/v1/auth/register` with `first_name`, `last_name`, `email`, `address`, and `password`. Backend validation and connection errors are shown in the register screen instead of creating a local mock account.

Database setup for PostgreSQL/PostGIS, local Docker, Supabase, migrations, and demo seed data is documented in [docs/database.md](docs/database.md).

## Mock Auth

Until the login backend is ready, sign-in uses frontend-only mock accounts. Registration calls the backend register endpoint and displays backend/network errors.
The resident SOS and responder incident queue are connected through an in-memory demo mode, so the judge demo works without a backend.

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

## Judge Demo Flow

Use this sequence to present the frontend as one disaster-response story:

1. Sign in as the resident user: `user123@gmail.com` / `12345678`.
2. Show the Emergency Backup Ready status and the AI Flood Forecast on Home.
3. Tap `SOS` and send the emergency request.
4. Open the Map tab and toggle `Incidents`, `Flood Risk`, `Safe Paths`, `Shelters`, and `Relay Points`.
5. Logout, then sign in as responder: `responder123@gmail.com` / `12345678`.
6. Show the responder dashboard receiving the resident request and live heatmap.
7. Open Active Incidents, tap a high-priority incident, and explain the AI Flood Prediction reasons.
8. Open Live Map to show routes, resources, evacuation centers, and hazard overlays.

## Maps

The Evacuation Map uses `flutter_map` with Mapbox raster tiles for a cleaner mobile demo. A demo token is already configured in `MapTileConfig`, so the app can run normally:

```sh
flutter run
```

If the Mapbox token is rotated, override it at launch:

```sh
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_TOKEN
```

The Evacuation Map should receive route and hazard geometry from FastAPI, then render it in Flutter as:

- green safe-route line
- red flooded-area polygons
- blue current-location marker
- evacuation-center markers

The map includes an ASEAN country selector. It recenters the map to the selected ASEAN country, but it does not calculate navigation by itself. FastAPI still needs to return country-specific evacuation centers, hazard polygons, blocked roads, and route geometry.

The locate button requests foreground location permission and centers the map on the user's current GPS location. On Android this uses `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`; on iOS this uses `NSLocationWhenInUseUsageDescription`.

For SentryMesh's disaster/offline scenario, add a local tile cache or packaged offline tile provider for target barangays before an emergency.
