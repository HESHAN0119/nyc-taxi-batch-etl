"""Database helpers shared by the ingestion modules."""

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
DATA_DIR = Path(os.getenv("DATA_DIR", "/opt/airflow/data"))
SQL_DIR = Path(os.getenv("SQL_DIR", "/opt/airflow/sql"))


def get_connection():
    "connection to the warehouse (Airflow connection postgres_dw)"
    c = PostgresHook.get_connection(DW_CONN_ID)
    return psycopg2.connect(host=c.host, port=c.port, dbname=c.schema, user=c.login, password=c.password)


def create_schema() -> None:
    "runs sql/schema.sql (safe to run again)"
    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            # lock so two DAGs don't create tables at the same time
            cur.execute("SELECT pg_advisory_xact_lock(1)")
            cur.execute((SQL_DIR / "schema.sql").read_text())
    finally:
        conn.close()
    log.info("Schema checked/created from schema.sql")


def load_csv_to_staging(df: pd.DataFrame, table: str) -> int:
    "replaces the table contents with the DataFrame (truncate + copy)"
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False)
    buffer.seek(0)

    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(f"TRUNCATE {table}")
            cur.copy_expert(f"COPY {table} ({', '.join(df.columns)}) FROM STDIN WITH (FORMAT csv)", buffer)
            return cur.rowcount
    finally:
        conn.close()


def run_sql_file(name: str, params: dict | None = None) -> list[int]:
    "runs all statements of a SQL file in one transaction, returns row counts"
    statements = [s for s in sqlparse.split((SQL_DIR / name).read_text()) if s.strip()]

    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            row_counts = []
            for statement in statements:
                cur.execute(statement, params)
                row_counts.append(cur.rowcount)
            return row_counts
    finally:
        conn.close()
