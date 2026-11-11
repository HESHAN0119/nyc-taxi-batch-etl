#!/usr/bin/env bash
# Starts the warehouse database and creates the schemas, tables and views.
# Usage: bash scripts/start_postgres.sh

set -e

SERVICE="dw-postgres"
CONTAINER="dw-postgres"
IMAGE="nyc-taxi-dw-postgres:16"
SCHEMA_FILE="sql/schema.sql"

# go to the project folder
cd "$(dirname "$0")/.."

# check Docker
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 1
fi

# start the container if needed
if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2> /dev/null)" = "true" ]; then
    echo "$CONTAINER is already running."
elif docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Image $IMAGE found. Starting $SERVICE..."
    docker compose up -d "$SERVICE"
else
    echo "Image $IMAGE not found. Building it and starting $SERVICE..."
    docker compose up -d --build "$SERVICE"
fi

# user and database from .env
DB_USER="$(grep '^DW_DB_USER=' .env | cut -d= -f2 | tr -d '\r')"
DB_NAME="$(grep '^DW_DB_NAME=' .env | cut -d= -f2 | tr -d '\r')"

# create the database if it is missing (\gexec runs the generated statement)
echo "Checking database $DB_NAME..."
docker exec -i "$CONTAINER" psql -q -U "$DB_USER" -d postgres <<SQL
SELECT 'CREATE DATABASE $DB_NAME'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$DB_NAME')
\gexec
SQL

# create schemas, tables and views
echo "Running $SCHEMA_FILE..."
docker exec -i "$CONTAINER" psql -q -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$SCHEMA_FILE"

# show what was created
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT table_schema AS schema,
           COUNT(*) FILTER (WHERE table_type = 'BASE TABLE') AS tables,
           COUNT(*) FILTER (WHERE table_type = 'VIEW')       AS views
    FROM information_schema.tables
    WHERE table_schema IN ('bronze', 'silver', 'gold')
    GROUP BY table_schema
    ORDER BY table_schema;"

echo "Done. Connect from Windows: localhost:5433 (user/password/database: see .env)"
