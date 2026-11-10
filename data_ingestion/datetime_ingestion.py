"""Datetime dimension (SCD Type 0 - a calendar never changes):
generates one row per hour between START_DATE and END_DATE into silver.dim_datetime (no CSV, no bronze).

Called from the Airflow DAG airflow/dags/datetime_dim.py:  load_dim_datetime()
"""

import logging

from data_ingestion.db import run_sql_file

log = logging.getLogger(__name__)

# Calendar range (inclusive). Widen it and re-run the DAG to add more hours; existing hours are kept.
START_DATE = "2023-01-01"    # first day of the taxi data
END_DATE = "2026-12-31"      # also covers the "yesterday" runs of taxi_daily_etl

DIM_SQL = "load_dim_datetime.sql"


def load_dim_datetime() -> int:
    "inserts every hour from START_DATE to END_DATE into silver.dim_datetime (existing hours are skipped)"
    [inserted] = run_sql_file(DIM_SQL, {"start_date": START_DATE, "end_date": END_DATE})
    log.info("dim_datetime: range=%s..%s inserted=%d", START_DATE, END_DATE, inserted)
    return inserted
