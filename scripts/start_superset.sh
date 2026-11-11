#!/usr/bin/env bash
# Starts Superset. Builds the image only if it does not exist.
# Usage: bash scripts/start_superset.sh

set -e

SERVICE="superset"
IMAGE="nyc-taxi-superset:6.1.0"

# go to the project folder
cd "$(dirname "$0")/.."

# UI port from .env
PORT="$(grep '^SUPERSET_HOST_PORT=' .env | cut -d= -f2 | tr -d '\r')"

# check Docker
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 1
fi

# start Superset if needed
running="$(docker compose ps --services --status running)"

if echo "$running" | grep -qx "$SERVICE"; then
    echo "Superset is already running."
elif docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Image $IMAGE found. Starting Superset..."
    docker compose up -d "$SERVICE"
else
    echo "Image $IMAGE not found. Building it and starting Superset (first time takes a few minutes)..."
    docker compose up -d --build "$SERVICE"
fi

docker compose ps -a superset-postgres superset-init "$SERVICE"

echo "Superset UI: http://localhost:${PORT:-8088}  (login: SUPERSET_ADMIN_USER / SUPERSET_ADMIN_PASSWORD in .env)"
echo "The UI can take about a minute to respond after a fresh start."
