#!/usr/bin/env bash
# Start Airflow (api-server, scheduler, dag-processor, triggerer).
#
#   bash scripts/start_airflow.sh
#
# Steps:
#   1. Docker is running?
#   2. all Airflow containers already running -> nothing to do
#      image already exists                   -> start without building
#      otherwise                              -> build the image, then start
#
# Docker Compose also starts what Airflow needs, if it is not running yet:
#   airflow-postgres (Airflow's own database), dw-postgres (the warehouse)
#   and airflow-init (runs once: prepares Airflow's database and creates the admin user).
# Nothing is deleted: DAG runs, users and warehouse data are kept in Docker volumes.

set -e

SERVICES="airflow-apiserver airflow-scheduler airflow-dag-processor airflow-triggerer"
IMAGE="nyc-taxi-airflow:3.3.2"        # built from airflow/Dockerfile

# Run from the project folder, where docker-compose.yml is.
cd "$(dirname "$0")/.."

# Airflow UI port, read from .env (tr removes Windows line endings).
PORT="$(grep '^AIRFLOW_HOST_PORT=' .env | cut -d= -f2 | tr -d '\r')"

# 1. Docker must be running.
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 1
fi

# 2. Start Airflow if needed.
running="$(docker compose ps --services --status running)"
missing=""
for service in $SERVICES; do
    if ! echo "$running" | grep -qx "$service"; then
        missing="$missing $service"
    fi
done

if [ -z "$missing" ]; then
    echo "Airflow is already running."
elif docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Not running:$missing"
    echo "Image $IMAGE found. Starting Airflow..."
    docker compose up -d $SERVICES
else
    echo "Image $IMAGE not found. Building it and starting Airflow (first time takes a few minutes)..."
    docker compose up -d --build $SERVICES
fi

# Show the state of all Airflow containers.
docker compose ps airflow-postgres $SERVICES

echo "Airflow UI: http://localhost:${PORT:-8888}  (login: AIRFLOW_ADMIN_USER / AIRFLOW_ADMIN_PASSWORD in .env)"
echo "The UI can take about a minute to respond after a fresh start."
