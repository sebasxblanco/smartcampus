# SmartCampus

Microservicio REST para gestionar las aulas y las reservas de una universidad, con un flujo de automatización completo: Git Hooks, Docker Compose y un pipeline de GitHub Actions que prueba, construye y despliega.

## Descripción

SmartCampus Solutions necesita que cada cambio llegue a producción probado y de forma reproducible. El proyecto cubre:

- **API REST** de aulas y reservas con sus reglas de negocio.
- **Tests automáticos** (unitarios y de integración) que se ejecutan antes de compartir cambios.
- **Calidad de código** comprobada automáticamente con Ruff.
- **Contenedores**: imagen Docker de la API y Docker Compose con PostgreSQL.
- **CI/CD**: GitHub Actions con matrix de Python, Secrets, build de la imagen y despliegue automático en un entorno persistente.

## Arquitectura

```
                 ┌──────────── docker compose (red smartcampus-net) ────────────┐
 cliente HTTP ──▶│ backend (FastAPI, puerto 8000) ──SQL──▶ database (PostgreSQL) │
                 │                                          volumen db-data      │
                 └──────────────────────────────────────────────────────────────┘
```

| Componente | Qué hace |
|---|---|
| `app/main.py` | Endpoints HTTP. Traduce cada error de negocio a su código HTTP en un solo sitio |
| `app/services.py` | Reglas de negocio. No sabe nada de HTTP: lanza `NotFoundError` (404), `InvalidDataError` (400) o `ConflictError` (409) |
| `app/models.py` | Tablas de la base de datos (SQLAlchemy) |
| `app/schemas.py` | Datos que entran y salen por HTTP, validados con Pydantic (capacidad <= 0 → 422) |
| `app/config.py` | Lee la configuración de variables de entorno: `DATABASE_URL` o, si no existe, la URL de PostgreSQL con las `DB_*` |

### Endpoints

| Método | Ruta | Respuesta |
|---|---|---|
| GET | `/health` | `{"status": "ok", "env": "..."}` |
| GET | `/rooms` · `/rooms/{id}` | Lista de aulas · un aula (404 si no existe) |
| POST | `/rooms` | 201 con el aula creada (422 si `capacidad <= 0`) |
| DELETE | `/rooms/{id}` | 204 (borra también sus reservas) · 404 si no existe |
| GET | `/bookings` | Lista de reservas |
| POST | `/bookings` | 201 · 404 si el aula no existe · 400 si `hora_inicio >= hora_fin` · 409 si se solapa |
| DELETE | `/bookings/{id}` | 204 · 404 si no existe |

Dos reservas se solapan si cada una empieza antes de que acabe la otra, en la misma aula y la misma fecha. Las contiguas (10:00-12:00 y 12:00-13:00) no se solapan.

## Instalación

Requisitos: Python 3.11 o 3.12, Docker con el plugin Compose y [uv](https://docs.astral.sh/uv/) (opcional, también vale `pip`).

```bash
git clone https://github.com/sebasxblanco/smartcampus.git
cd smartcampus
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements-dev.txt
sh scripts/install-hooks.sh        # activa los Git Hooks (ver abajo)
cp .env.example .env               # y poner una contraseña real en DB_PASSWORD
```

## Ejecución local (sin Docker)

```bash
DATABASE_URL=sqlite+pysqlite:///./smartcampus.db uvicorn app.main:app --reload
```

Documentación interactiva en http://localhost:8000/docs.

## Docker

```bash
docker build -t smartcampus .
docker run --rm -p 8000:8000 \
  -e DATABASE_URL=sqlite+pysqlite:////tmp/smartcampus.db smartcampus
curl http://localhost:8000/health
```

La imagen parte de `python:3.12-slim`, instala solo las dependencias de ejecución (los tests y las herramientas de desarrollo se quedan fuera gracias a `.dockerignore`), ejecuta la app con un usuario sin privilegios y declara un `HEALTHCHECK` contra `/health`.

## Docker Compose

```bash
docker compose up --build -d
docker compose ps            # los dos servicios en "healthy"
curl http://localhost:8000/rooms
docker compose down          # los datos se conservan en el volumen db-data
```

| Elemento | Configuración |
|---|---|
| Servicios | `backend` (la imagen de este repo) y `database` (`postgres:18`, imagen oficial) |
| Variables | Se leen de `.env` (plantilla en `.env.example`). El `.env` real está en `.gitignore` |
| Red | `smartcampus-net`: el backend llega a la base de datos por su nombre de servicio, `database` |
| Puertos | Solo se publica el backend (`APP_PORT`, 8000 por defecto). PostgreSQL no se expone fuera |
| Healthchecks | `pg_isready` en la base de datos y `/health` en el backend |
| Dependencias | El backend espera a que la base de datos esté `healthy` (`depends_on` con `condition`) |
| Persistencia | Volumen `db-data` |
| Reinicio | `restart: unless-stopped` en los dos servicios |

## Tests

```bash
pytest                  # todos
pytest -m unit          # solo unitarios (reglas de negocio, sin HTTP)
pytest -m integration   # solo integración (los 8 endpoints por HTTP)
```

Los tests usan SQLite en memoria, así que no necesitan Docker ni PostgreSQL. Los marcadores `unit` e `integration` están declarados en `pyproject.toml`.

## Git Hooks

`.git/hooks/` no se sube al repositorio, así que los hooks viven en `.githooks/` (versionados) y `scripts/install-hooks.sh` le dice a Git que los use (`git config core.hooksPath .githooks`).

| Hook | Qué hace | Si falla |
|---|---|---|
| `pre-commit` | `ruff format --check`, `ruff check` y `pytest -m unit` | `❌ Commit rechazado` y el commit no se crea |
| `post-commit` | Añade a `commit-log.txt` autor, fecha, hash y mensaje | No bloquea: el commit ya existe |
| `pre-push` | `pytest -m "unit or integration"` | `❌ Push rechazado: existen tests fallidos`. Si pasa: `✅ Todos los tests superados` |
| `post-push` | Muestra `🚀 Cambios enviados correctamente al repositorio remoto.` y registra el push en `push-log.txt` | Solo informa |

**`post-push` no existe en Git.** Se emula con el alias `git pushx`, que crea el script de instalación:

```bash
git config alias.pushx '!f() { git push "$@" && .githooks/post-push; }; f'
```

`git pushx` acepta los mismos argumentos que `git push` y solo lanza el post-push si el push ha terminado bien (`&&`). `commit-log.txt` y `push-log.txt` se generan en cada equipo y están en `.gitignore`.

## GitHub Actions

Workflow: `.github/workflows/ci-cd.yml`. Se ejecuta con cada `push` y cada `pull_request`.

```
quality ──▶ test (3.11) ──┐
        └─▶ test (3.12) ──┴─▶ build + validación ──▶ deploy (solo push a main)
```

| Job | Qué hace |
|---|---|
| `quality` | Ruff: las mismas comprobaciones que el pre-commit |
| `test` | `pytest` en **matrix con Python 3.11 y 3.12** |
| `build` | `docker build` (solo si los tests pasan en las dos versiones) y **validación**: levanta el Compose con PostgreSQL, comprueba `/health`, crea un aula y la lee |
| `deploy` | En el **self-hosted runner**: `docker compose up -d --build --wait` y comprobación de `/health`. No se ejecuta en Pull Requests |

**Variables:** `IMAGE_NAME` en el workflow, y `APP_ENV`, `DB_NAME`, `DB_USER` y `DEPLOY_PORT` como variables del repositorio (`vars.*`) con valor por defecto.

**Secrets:** `DB_PASSWORD` (Settings → Secrets and variables → Actions). Entra en los pasos como variable de entorno y `scripts/write-env.sh` lo escribe en el `.env` sin imprimirlo; en los logs GitHub lo enmascara como `***`. No aparece en el código ni en el repositorio.

## Despliegue

El job `deploy` corre en un **self-hosted runner** instalado en el equipo que hace de servidor (opción A del enunciado). El entorno es persistente: los contenedores siguen en marcha cuando el pipeline termina, a diferencia de un runner de GitHub, que se destruye al acabar el job.

- Proyecto de Compose `smartcampus-prod` y puerto `DEPLOY_PORT` (8080 por defecto), para no chocar con el entorno de desarrollo.
- Solo despliega lo que entra en `main` por `push`. El repositorio es privado: GitHub desaconseja runners propios en repos públicos, porque un PR podría ejecutar código en la máquina.

Instalación del runner: Settings → Actions → Runners → New self-hosted runner (Linux x64) y seguir los comandos que muestra GitHub (`config.sh` con el token y `run.sh`, o `svc.sh install` para dejarlo como servicio). El usuario del runner tiene que poder usar Docker.

## Evidencias

Capturas en `docs/evidencias/`.

| Evidencia | Prueba | Captura |
|---|---|---|
| Tests pasando | `pytest -v` | [docs/evidencias/tests.png](docs/evidencias/tests.png) |
| pre-commit bloquea / deja pasar | Commit con código mal formateado · commit limpio | [docs/evidencias/hooks-pre-commit.png](docs/evidencias/hooks-pre-commit.png) |
| post-commit | `cat commit-log.txt` | [docs/evidencias/hooks-post-commit.png](docs/evidencias/hooks-post-commit.png) |
| pre-push bloquea / deja pasar · post-push | `git pushx` con un test roto · con todo en verde | [docs/evidencias/hooks-push.png](docs/evidencias/hooks-push.png) |
| Imagen Docker | `docker build` y `docker run` | [docs/evidencias/docker.png](docs/evidencias/docker.png) |
| Compose | `docker compose ps` con los servicios `healthy` | [docs/evidencias/compose.png](docs/evidencias/compose.png) |
| Pipeline en verde y matrix | Pestaña Actions | [docs/evidencias/pipeline.png](docs/evidencias/pipeline.png) |
| Disparo por push y por pull request | `gh run list` | [docs/evidencias/pipeline-ejecuciones.png](docs/evidencias/pipeline-ejecuciones.png) |
| Secrets | Log del pipeline con `***` | [docs/evidencias/secrets.png](docs/evidencias/secrets.png) |
| Despliegue | Job `deploy` y `/health` en el puerto de producción | [docs/evidencias/deploy.png](docs/evidencias/deploy.png) |
