#!/bin/sh
# Crea el .env que lee docker-compose.yml a partir de variables de entorno.
# En GitHub Actions, DB_PASSWORD llega desde un Secret: se escribe sin imprimirlo.
set -e

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Falta DB_PASSWORD (Secret del repositorio)"
    exit 1
fi

{
    echo "APP_ENV=${APP_ENV:-production}"
    echo "APP_PORT=${APP_PORT:-8000}"
    echo "DB_NAME=${DB_NAME:-smartcampus}"
    echo "DB_USER=${DB_USER:-smartcampus}"
    printf 'DB_PASSWORD=%s\n' "$DB_PASSWORD"
} > .env

echo "✅ .env creado (la contraseña no se muestra)"
