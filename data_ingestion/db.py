"""Shared database helpers for the reference data ingestion files (vendor, payment_type, rate_code, location)."""

import io
import logging
import os
from pathlib import Path

import pandas as pd
import psycopg2
import sqlparse
from airflow.providers.postgres.hooks.postgres import PostgresHook

log = logging.getLogger(__name__)

DW_CONN_ID = "postgres_dw"
DATA_DIR = Path(os.getenv("DATA_DIR", "/opt/airflow/data"))   # project data/ folder, mounted in the container
SQL_DIR = Path(os.getenv("SQL_DIR", "/opt/airflow/sql"))       # project sql/ folder, mounted in the container


def get_connection():
    "opens a connection to the warehouse using the Airflow connection postgres_dw (credentials come from .env)"
    c = PostgresHook.get_connection(DW_CONN_ID)
    return psycopg2.connect(host=c.host, port=c.port, dbname=c.schema, user=c.login, password=c.password)


def create_schema() -> None:
    "runs sql/schema.sql (safe to repeat: IF NOT EXISTS everywhere)"
    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            # Several DAGs may start at once: this lock makes them create tables one at a time.
            cur.execute("SELECT pg_advisory_xact_lock(1)")
            cur.execute((SQL_DIR / "schema.sql").read_text())
    finally:
        conn.close()
    log.info("Schema checked/created from schema.sql")


def load_csv_to_staging(df: pd.DataFrame, table: str) -> int:
    "replaces the contents of a bronze table with the DataFrame (one transaction: TRUNCATE, then COPY)"
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False)
    buffer.seek(0)

    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:            # commit on success, rollback on error
            cur.execute(f"TRUNCATE {table}")        # full refresh: no duplicates between loads
            cur.copy_expert(f"COPY {table} ({', '.join(df.columns)}) FROM STDIN WITH (FORMAT csv)", buffer)
            return cur.rowcount                     # COPY fails on a duplicate code (primary key)
    finally:
        conn.close()


def run_sql_file(name: str, params: dict | None = None) -> list[int]:
    "runs every statement of sql/<name> in one transaction; returns the rows affected by each statement"
    statements = [s for s in sqlparse.split((SQL_DIR / name).read_text()) if s.strip()]

    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            row_counts = []
            for statement in statements:
                cur.execute(statement, params)      # params fill %(name)s placeholders, e.g. %(start_date)s
                row_counts.append(cur.rowcount)
            return row_counts
    finally:
        conn.close()
