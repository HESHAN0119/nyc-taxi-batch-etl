"""Loads one day from bronze.stg_taxi_trips into silver.fact_taxi_trips (delete + insert)."""

import logging

from data_ingestion.db import run_sql_file
from data_ingestion.raw_data_ingestion import take_d_1_date

log = logging.getLogger(__name__)

FACT_SQL = "load_fact_taxi_trips.sql"


def load_fact_taxi_trips() -> dict:
    "reloads one day of the fact table"
    load_date = take_d_1_date()
    log.info("Fact load started: load_date=%s", load_date)

    deleted, inserted = run_sql_file(FACT_SQL, {"load_date": load_date})

    log.info("Fact load finished: load_date=%s deleted=%d inserted=%d", load_date, deleted, inserted)
    return {"load_date": load_date.isoformat(), "deleted": deleted, "inserted": inserted}
