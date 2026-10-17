# SmartCampus

Microservicio REST para gestionar aulas y reservas, con Git Hooks, Docker Compose y GitHub Actions.

> En construcción. Las secciones se completan por fases.

## Instalación

```bash
uv venv --python 3.12
source .venv/bin/activate
uv pip install -r requirements-dev.txt
```

## Ejecución local

```bash
uvicorn app.main:app --reload
```

## Tests

```bash
pytest                  # todos
pytest -m unit          # solo unitarios
pytest -m integration   # solo integración
```
