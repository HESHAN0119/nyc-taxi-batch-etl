"""Fact table: incremental load of one day, bronze.stg_taxi_trips -> silver.fact_taxi_trips.

Method: delete + insert by day. The day's old rows are deleted, then the day is inserted again from
bronze, in one transaction. Re-running a day replaces it; days can be loaded in any order.

The day comes from take_d_1_date() (same Python function as the trip ingestion), not from Airflow.
Called from the Airflow DAG airflow/dags/taxi_daily_etl.py:  load_fact_taxi_trips()
"""

import logging

from data_ingestion.db import run_sql_file
from data_ingestion.raw_data_ingestion import take_d_1_date

log = logging.getLogger(__name__)

FACT_SQL = "load_fact_taxi_trips.sql"    # 1. delete the day  2. insert the day from bronze


def load_fact_taxi_trips() -> dict:
    "replaces one day of silver.fact_taxi_trips with that day's rows from bronze"
    load_date = take_d_1_date()
    log.info("Fact load started: load_date=%s", load_date)

    deleted, inserted = run_sql_file(FACT_SQL, {"load_date": load_date})

    log.info("Fact load finished: load_date=%s deleted=%d inserted=%d", load_date, deleted, inserted)
    return {"load_date": load_date.isoformat(), "deleted": deleted, "inserted": inserted}
