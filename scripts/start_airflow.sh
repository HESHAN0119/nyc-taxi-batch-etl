#!/usr/bin/env bash
# Starts Airflow. Builds the image only if it does not exist.
# Usage: bash scripts/start_airflow.sh

set -e

SERVICES="airflow-apiserver airflow-scheduler airflow-dag-processor airflow-triggerer"
IMAGE="nyc-taxi-airflow:3.3.2"

# go to the project folder
cd "$(dirname "$0")/.."

# UI port from .env
PORT="$(grep '^AIRFLOW_HOST_PORT=' .env | cut -d= -f2 | tr -d '\r')"

# check Docker
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 1
fi

# start the containers that are not running
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

docker compose ps airflow-postgres $SERVICES

echo "Airflow UI: http://localhost:${PORT:-8888}  (login: AIRFLOW_ADMIN_USER / AIRFLOW_ADMIN_PASSWORD in .env)"
echo "The UI can take about a minute to respond after a fresh start."
