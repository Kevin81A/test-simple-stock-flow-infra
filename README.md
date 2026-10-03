# Simple Stock Flow · Infrastructure & Containers

> **SDD Technical Assessment · SENA ADSO Class 3413974**  
> Service definition and orchestration via Docker Compose with MySQL 8.4 LTS, backend API, and Nginx frontend.

---

## 1. What is this repository and what role does it play in Simple Stock Flow?

This repository contains the **container and network orchestration** (`docker-compose.yml`) for the entire *Simple Stock Flow* solution.
It serves as the **runtime environment coordinator**, provisioning:
- `db`: **MySQL 8.4 LTS** database engine configured with strict sql-mode and `utf8mb4` encoding. **Starts with a completely empty database** (ADR-001: the API owns the schema via automated migrations).
- `api`: Backend service in **PHP 8.2 + Laravel 11**, configured to run migrations, seed the initial administrator user if not present, and serve on internal port `8000`.
- `app`: **Nginx** web server hosting the **React 18** Single Page Application on port `8080` and acting as a reverse proxy for `/api/` requests and `/media/` static asset volume.
- Named persistent volumes: `db_data`, `api_vendor`, `media_data`.

---

## 2. How to run it locally?

### With Docker Compose (Production / Assessment Mode)
The repositories must be cloned as sibling directories. From the `test-simple-stock-flow-infra` folder:

```bash
# 1. Copy environment variables
cp .env.example .env

# 2. Start services in background
docker compose up -d --build

# 3. Check container status and health
docker compose ps
```

Access points once running:
- **Frontend SPA (Nginx):** `http://localhost:8080`
- **Backend API (Laravel):** `http://localhost:8000` (or via `http://localhost:8080/api/`)
- **Healthcheck:** `http://localhost:8000/health`

### With Docker Compose (Development Mode)
If you wish to expose the database port (3306) to the host machine:
```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### Stopping Services
```bash
docker compose down
# Or to reset and wipe persistent data volumes:
docker compose down -v
```

---

## 3. Required Environment Variables

The `.env` file (based on `.env.example`) controls service configuration:

| Variable | Description | Default Value |
|---|---|---|
| `DB_ROOT_PASSWORD` | Root password for MySQL engine | `rootsecret` |
| `DB_DATABASE` | System database name | `stockflow` |
| `DB_USERNAME` | Application database user | `stockflow` |
| `DB_PASSWORD` | Application database user password | `stockflowpass` |
| `JWT_SIGNING_KEY` | Symmetric secret key for HS256 JWT tokens | Required in production |
| `ADMIN_EMAIL` | Initial admin user email | `admin@stockflow.com` |
| `ADMIN_PASSWORD` | Initial admin user password | Required in production |

*Security note (Article IX): Insecure default passwords are strictly prohibited for administrative credentials in production environments.*

---

## 4. How are tests and verification probes executed?

The repository includes automated test suites covering all verification probes (P-01 through P-42):

### On Linux / macOS / Git Bash:
```bash
chmod +x verify.sh
./verify.sh
```

### On Windows (PowerShell):
```powershell
.\verify.ps1
```

The script automatically verifies:
1. Backend healthcheck returns 200 OK.
2. Invariant D-C9: 401 Unauthorized returns strictly empty body (`Content-Length: 0`).
3. Invariant D-C9: 404 Not Found returns strictly empty body (`Content-Length: 0`).
4. Initial administrator authentication and JWT token issuance.
5. Invariable presence of all 5 fixed seed categories.
6. Validation errors return HTTP 400 under RFC 7807 (`application/problem+json` with `detail` and `errors`).
7. Availability and rendering of the React application served by Nginx.

---

## 5. Relevant Technical Decisions Taken During Implementation

1. **Strict Compliance with ADR-001 (Schema Ownership):**
   - The `db` container does not include any SQL or DDL files in `/docker-entrypoint-initdb.d/`. The schema and the 5 immutable seed categories are created and versioned solely by Laravel migrations when the `api` container boots.
2. **Chained Healthchecks with Conditional `depends_on`:**
   - `api` waits for `db` to be `healthy` using `mysqladmin ping`.
   - `app` waits for `api` to be `healthy` using `wget http://localhost:8000/health`.
   - This eliminates race condition connection failures during cold boots.
3. **Shared Volume `media_data`:**
   - The API writes uploaded product images to `/var/www/media`, and Nginx (`app`) mounts this volume as read-only (`:ro`) to serve files with high throughput at `/media/` with `client_max_body_size 6m`.
