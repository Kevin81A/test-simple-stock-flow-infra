# Simple Stock Flow · Infraestructura y Contenedores

> **Prueba técnica SDD · Ficha ADSO 3413974**  
> Definición y orquestación de servicios en Docker Compose con MySQL 8.4 LTS, backend API y frontend Nginx.

---

## 1. ¿Qué es este repositorio y qué rol cumple en Simple Stock Flow?

Este repositorio contiene la **orquestación de contenedores y redes** (`docker-compose.yml`) de la solución completa *Simple Stock Flow*.
Cumple el rol de **coordinador del entorno de ejecución**, levantando:
- `db`: Motor de base de datos **MySQL 8.4 LTS**, con sql-mode estricto y codificación `utf8mb4`. **Inicia con la base de datos completamente vacía** (ADR-001: la API es la dueña del esquema mediante migraciones automáticas).
- `api`: Servicio backend en **PHP 8.2 + Laravel 11**, configurado para ejecutar migraciones, sembrar el usuario administrador inicial si no existe, e iniciar en el puerto interno `8000`.
- `app`: Servidor web **Nginx** que sirve la Single Page Application en **React 18** en el puerto `8080` y actúa como proxy inverso para las peticiones a `/api/` y el volumen de medios `/media/`.
- Volúmenes persistentes con nombres explícitos: `db_data`, `api_vendor`, `media_data`.

---

## 2. ¿Cómo se ejecuta localmente?

### Con Docker Compose (Modo Producción / Evaluación)
Los repositorios deben estar clonados como directorios hermanos. Desde la carpeta `test-simple-stock-flow-infra`:

```bash
# 1. Copiar variables de entorno
cp .env.example .env

# 2. Levantar los servicios en segundo plano
docker compose up -d --build

# 3. Comprobar el estado y salud de los contenedores
docker compose ps
```

Puntos de acceso una vez levantado:
- **Frontend SPA (Nginx):** `http://localhost:8080`
- **Backend API (Laravel):** `http://localhost:8000` (o a través de `http://localhost:8080/api/`)
- **Healthcheck:** `http://localhost:8000/health`

### Con Docker Compose (Modo Desarrollo)
Si se desea exponer el puerto de la base de datos (3306) al host:
```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### Detener los servicios
```bash
docker compose down
# O para reiniciar limpiando volúmenes de datos:
docker compose down -v
```

---

## 3. Variables de entorno requeridas

El archivo `.env` (basado en `.env.example`) controla la configuración:

| Variable | Descripción | Valor por Defecto |
|---|---|---|
| `DB_ROOT_PASSWORD` | Contraseña root del motor MySQL | `rootsecret` |
| `DB_DATABASE` | Nombre de la base de datos del sistema | `stockflow` |
| `DB_USERNAME` | Usuario de la aplicación | `stockflow` |
| `DB_PASSWORD` | Contraseña del usuario de base de datos | `stockflowpass` |
| `JWT_SIGNING_KEY` | Clave secreta para firma simétrica HS256 | Requerido en producción |
| `ADMIN_EMAIL` | Correo del administrador inicial | `admin@stockflow.com` |
| `ADMIN_PASSWORD` | Contraseña del administrador inicial | Requerido en producción |

*Nota de seguridad (Artículo IX): No se permiten valores por defecto inseguros para credenciales de administración en entornos de producción.*

---

## 4. ¿Cómo se ejecutan las pruebas y sondas de verificación?

El repositorio incluye suites de comprobación automatizada de las sondas de verificación (P-01 a P-42):

### En Linux / macOS / Git Bash:
```bash
chmod +x verify.sh
./verify.sh
```

### En Windows (PowerShell):
```powershell
.\verify.ps1
```

El script verifica automáticamente:
1. Healthcheck 200 OK del backend.
2. Invariante D-C9: 401 sin autenticación con cuerpo estrictamente vacío (`Content-Length: 0`).
3. Invariante D-C9: 404 ruta no encontrada con cuerpo estrictamente vacío (`Content-Length: 0`).
4. Autenticación del usuario administrador inicial y emisión de token JWT.
5. Presencia inmutable de las 5 categorías semilla fijas.
6. Errores de validación 400 bajo especificación RFC 7807 (`application/problem+json` con `detail` y `errors`).
7. Disponibilidad y renderizado de la aplicación React servida por Nginx.

---

## 5. Decisiones técnicas relevantes tomadas durante la implementación

1. **Cumplimiento Estricto de ADR-001 (Dueño del Esquema):**
   - El contenedor `db` no incluye ningún archivo SQL ni DDL en `/docker-entrypoint-initdb.d/`. El esquema y las 5 categorías fijas son creadas y versionadas exclusivamente por las migraciones de Laravel al arrancar el contenedor `api`.
2. **Healthchecks en Cadena con `depends_on` Condicional:**
   - `api` espera a que `db` reporte estado `healthy` mediante `mysqladmin ping`.
   - `app` espera a que `api` reporte estado `healthy` mediante `wget http://localhost:8000/health`.
   - Esto evita fallos de conexión por condiciones de carrera durante el arranque inicial.
3. **Volumen Compartido `media_data`:**
   - La API escribe las imágenes subidas por los usuarios en `/var/www/media`, y el contenedor Nginx (`app`) monta dicho volumen como solo lectura (`:ro`) para servirlas a alta velocidad en `/media/` con `client_max_body_size 6m`.
