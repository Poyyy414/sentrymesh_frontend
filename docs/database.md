# Database Setup

SentryMesh uses PostgreSQL with PostGIS. The local Docker setup and Supabase both use PostgreSQL, so the same SQLAlchemy models and Alembic migrations work for either target.

For frontend/backend endpoint contracts, see [API documentation](api.md).

## Local Docker Database

Start the database:

```sh
docker compose up -d db
```

The local database is exposed on host port `5433` to avoid conflicts with an existing local PostgreSQL installation. Docker services still use port `5432` internally.

Run migrations:

```sh
POSTGRES_PORT=5433 \
alembic upgrade head
```

Run the API after the database is healthy:

```sh
docker compose up backend
```

## Supabase Database

Use the Supabase pooler connection string for local development, because the direct database host may resolve to IPv6 only on some networks. Set:

```sh
SQLALCHEMY_DATABASE_URI=postgresql+asyncpg://postgres.YOUR_PROJECT_REF:YOUR_PASSWORD@aws-1-ap-southeast-2.pooler.supabase.com:6543/postgres
```

Then run:

```sh
docker compose run --rm backend alembic upgrade head
```

Seed demo data:

```sh
docker compose run --rm backend python scripts/seed_demo_data.py
```

## Initial Tables

The first migration creates:

- `users`
- `alerts`
- `rescue_requests`
- `sensor_nodes`
- `sensor_readings`
- `safe_routes`
- `family_members`
- `community_reports`
- `evacuation_centers`
- `blocked_roads`

Geometry fields use SRID `4326` for standard latitude/longitude data.

## Demo Seed Data

The demo seed adds Naga City sample records for the resident app, responder dashboard, live map, and rescue workflow:

- 2 users
- 3 alerts
- 3 rescue requests
- 4 sensor nodes
- 4 sensor readings
- 2 safe routes
- 3 family members
- 3 community reports
- 3 evacuation centers
- 2 blocked roads
