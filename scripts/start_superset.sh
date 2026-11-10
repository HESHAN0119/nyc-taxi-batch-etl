#!/usr/bin/env bash
# Start Superset (dashboards).
#
#   bash scripts/start_superset.sh
#
# Steps:
#   1. Docker is running?
#   2. Superset already running -> nothing to do
#      image already exists     -> start without building
#      otherwise                -> build the image, then start
#
# Docker Compose also starts what Superset needs, if it is not running yet:
#   superset-postgres (Superset's own database), dw-postgres (the warehouse)
#   and superset-init (runs once per start: prepares Superset's database, the admin user
#   and the "NYC Taxi DW" connection - it never deletes charts or dashboards).
# Nothing is deleted: users, charts and dashboards are kept in a Docker volume.

set -e

SERVICE="superset"
IMAGE="nyc-taxi-superset:6.1.0"       # built from superset/Dockerfile

# Run from the project folder, where docker-compose.yml is.
cd "$(dirname "$0")/.."

# Superset UI port, read from .env (tr removes Windows line endings).
PORT="$(grep '^SUPERSET_HOST_PORT=' .env | cut -d= -f2 | tr -d '\r')"

# 1. Docker must be running.
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 1
fi

# 2. Start Superset if needed.
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

# Show the state of the Superset containers (superset-init shows "Exited (0)" when its setup succeeded).
docker compose ps -a superset-postgres superset-init "$SERVICE"

echo "Superset UI: http://localhost:${PORT:-8088}  (login: SUPERSET_ADMIN_USER / SUPERSET_ADMIN_PASSWORD in .env)"
echo "The UI can take about a minute to respond after a fresh start."
