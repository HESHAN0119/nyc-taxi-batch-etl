#!/usr/bin/env bash
# Start the warehouse database (container dw-postgres) and create its database, schemas, tables and views.
#
#   bash scripts/start_postgres.sh
#
# Steps:
#   1. Docker is running?
#   2. container already running        -> skip starting
#      image already exists             -> start without building
#      otherwise                        -> build the image, then start
#   3. create the database (taxi_dw) if it does not exist
#   4. run sql/schema.sql: schemas -> tables -> indexes -> views
#
# Safe to run any time: nothing is dropped, existing tables and data are kept
# (schema.sql uses IF NOT EXISTS / CREATE OR REPLACE). Data lives in the volume dw-pgdata.

set -e

SERVICE="dw-postgres"                 # service name in docker-compose.yml
CONTAINER="dw-postgres"               # container_name in docker-compose.yml
IMAGE="nyc-taxi-dw-postgres:16"       # image built from postgres/Dockerfile
SCHEMA_FILE="sql/schema.sql"

# Run from the project folder, where docker-compose.yml is.
cd "$(dirname "$0")/.."

# 1. Docker must be running.
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again."
    exit 1
fi

# 2. Start the container if needed.
if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2> /dev/null)" = "true" ]; then
    echo "$CONTAINER is already running."
elif docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "Image $IMAGE found. Starting $SERVICE..."
    docker compose up -d "$SERVICE"
else
    echo "Image $IMAGE not found. Building it and starting $SERVICE..."
    docker compose up -d --build "$SERVICE"
fi

# User and database name, read from .env (tr removes Windows line endings).
DB_USER="$(grep '^DW_DB_USER=' .env | cut -d= -f2 | tr -d '\r')"
DB_NAME="$(grep '^DW_DB_NAME=' .env | cut -d= -f2 | tr -d '\r')"

# 3. Create the database if it does not exist.
#    The SELECT returns a CREATE DATABASE statement only when the database is missing; \gexec runs it.
#    (No output is captured into variables: in Git Bash, captured 'docker exec' output can contain
#    a "failed to get console mode" warning.)
echo "Checking database $DB_NAME..."
docker exec -i "$CONTAINER" psql -q -U "$DB_USER" -d postgres <<SQL
SELECT 'CREATE DATABASE $DB_NAME'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$DB_NAME')
\gexec
SQL

# 4. Create schemas, tables, indexes and views (stops at the first error).
echo "Running $SCHEMA_FILE..."
docker exec -i "$CONTAINER" psql -q -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$SCHEMA_FILE"

# Show what exists now.
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT table_schema AS schema,
           COUNT(*) FILTER (WHERE table_type = 'BASE TABLE') AS tables,
           COUNT(*) FILTER (WHERE table_type = 'VIEW')       AS views
    FROM information_schema.tables
    WHERE table_schema IN ('bronze', 'silver', 'gold')
    GROUP BY table_schema
    ORDER BY table_schema;"

echo "Done. Connect from Windows: localhost:5433 (user/password/database: see .env)"
