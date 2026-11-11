"""Fills silver.dim_datetime with one row per hour. Used by the datetime_dim DAG."""

import logging

from data_ingestion.db import run_sql_file

log = logging.getLogger(__name__)

# Calendar range (both included)
START_DATE = "2023-01-01"
END_DATE = "2026-12-31"

DIM_SQL = "load_dim_datetime.sql"


def load_dim_datetime() -> int:
    "inserts the hours that are not there yet"
    [inserted] = run_sql_file(DIM_SQL, {"start_date": START_DATE, "end_date": END_DATE})
    log.info("dim_datetime: range=%s..%s inserted=%d", START_DATE, END_DATE, inserted)
    return inserted
